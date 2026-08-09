import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/enums/transfer_status.dart';
import '../../../core/services/api_exception.dart';
import '../../../core/services/core_providers.dart';
import '../../../core/services/platform_service.dart';
import '../../files/controller/files_controller.dart';
import '../../files/providers/files_providers.dart';
import '../../offline/controller/offline_controller.dart';
import '../db/download_sink.dart';
import '../db/transfer_store.dart';
import '../db/tus_uploader.dart';
import '../db/upload_source.dart';
import '../models/transfer_model.dart';

final transferStoreProvider = Provider<TransferStore>((ref) {
  return TransferStore(ref.watch(localDbProvider));
});

final tusUploaderProvider = Provider<TusUploader>((ref) {
  return TusUploader(ref.watch(apiClientProvider));
});

/// The transfer engine.
///
/// A transfer is queued, in progress, retrying with a visible reason, or
/// failed with a clear reason and a retry button. There is no fourth, silent
/// state, and nothing here ever fails quietly.
class TransferController extends Notifier<List<TransferModel>> {
  final Map<String, CancelToken> _cancels = <String, CancelToken>{};
  Timer? _pump;
  bool _online = true;
  bool _restored = false;
  bool _serviceRunning = false;

  TransferStore get _store => ref.read(transferStoreProvider);
  TusUploader get _uploader => ref.read(tusUploaderProvider);

  @override
  List<TransferModel> build() {
    // the queue pauses cleanly the moment the connection drops, rather than
    // letting every in-flight item independently discover that
    ref.listen(connectivityProvider, (previous, next) {
      next.whenData((online) {
        _online = online;
        if (online) {
          _resumeAfterReconnect();
        } else {
          _pauseAll();
        }
      });
    });

    ref.onDispose(() {
      _pump?.cancel();
      for (final token in _cancels.values) {
        token.cancel('disposed');
      }
    });

    unawaited(_restore());
    return const <TransferModel>[];
  }

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    final saved = await _store.load();
    // anything that was mid-flight when the app died goes back to queued, so
    // it picks up from its last acknowledged byte rather than being lost
    state = saved
        .map((transfer) => transfer.status == TransferStatus.inProgress
            ? transfer.copyWith(status: TransferStatus.queued)
            : transfer)
        .toList();
    _schedulePump();
  }

  Future<void> _persist() async => _store.save(state);

  void _replace(TransferModel next) {
    state = <TransferModel>[
      for (final transfer in state)
        if (transfer.id == next.id) next else transfer,
    ];
    // one row, not the whole queue: this runs on every progress tick of every
    // in flight transfer, and rewriting the queue each time would not scale
    unawaited(_store.upsert(next));
  }

  TransferModel? _byId(String id) {
    for (final transfer in state) {
      if (transfer.id == id) return transfer;
    }
    return null;
  }

  /// Enqueues files. They are written to durable storage first, before any
  /// network call starts, so the intent survives an app kill a second later.
  ///
  /// Returns how many were actually accepted. A caller that reports success
  /// needs to know, because a path that has gone away is skipped here and
  /// telling someone their drop worked when nothing queued is worse than
  /// telling them it did not.
  Future<int> enqueueUploads({
    required List<String?> paths,
    String parentId = '',
    String nodeId = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final additions = <TransferModel>[];

    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      final source = FileUploadSource(path);
      if (!await source.exists()) continue;
      additions.add(
        TransferModel(
          id: 'up-$now-${additions.length}-${path.hashCode}',
          kind: TransferKind.upload,
          name: p.basename(path),
          status: TransferStatus.queued,
          localPath: path,
          parentId: parentId,
          nodeId: nodeId,
          totalBytes: await source.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await _addAll(additions);
    return additions.length;
  }

  /// Enqueues uploads from contents rather than paths.
  ///
  /// This is what a browser gives: it hands over the bytes and never a path,
  /// because a page cannot see the filesystem. The bytes are held in memory
  /// for the life of the upload, so they are dropped as soon as it finishes,
  /// fails, or is cancelled.
  Future<int> enqueueUploadBytes({
    required List<({String name, Uint8List bytes})> files,
    String parentId = '',
    String nodeId = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final additions = <TransferModel>[];

    for (final file in files) {
      if (file.name.isEmpty || file.bytes.isEmpty) continue;
      final id = 'up-$now-${additions.length}-${file.name.hashCode}';
      InMemorySources.instance.put(id, BytesUploadSource(file.bytes));
      additions.add(
        TransferModel(
          id: id,
          kind: TransferKind.upload,
          name: file.name,
          status: TransferStatus.queued,
          // deliberately empty: there is no path, and writing a fake one would
          // make a resume after restart look possible when it is not
          localPath: '',
          parentId: parentId,
          nodeId: nodeId,
          totalBytes: file.bytes.length,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await _addAll(additions);
    return additions.length;
  }

  Future<void> _addAll(List<TransferModel> additions) async {
    if (additions.isEmpty) return;
    state = <TransferModel>[...state, ...additions];
    await _persist();
    _schedulePump();
  }

  /// Where a transfer's bytes come from: a file on disk, or the contents a
  /// browser handed over.
  UploadSource? _sourceFor(TransferModel transfer) {
    final held = InMemorySources.instance.get(transfer.id);
    if (held != null) return held;
    if (transfer.localPath.isEmpty) return null;
    return FileUploadSource(transfer.localPath);
  }

  /// Enqueues downloads. Same durability rule as uploads: the intent is
  /// written before any byte moves, so closing the app mid download resumes
  /// rather than restarts.
  Future<void> enqueueDownloads(
    List<({String nodeId, String name, int sizeBytes})> items,
  ) async {
    if (items.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    final additions = <TransferModel>[
      for (var i = 0; i < items.length; i++)
        TransferModel(
          id: 'down-$now-$i-${items[i].nodeId}',
          kind: TransferKind.download,
          name: items[i].name,
          status: TransferStatus.queued,
          nodeId: items[i].nodeId,
          totalBytes: items[i].sizeBytes,
          createdAt: now,
          updatedAt: now,
        ),
    ];

    state = <TransferModel>[...state, ...additions];
    await _persist();
    _schedulePump();
  }

  /// Enqueues a download of a public link. The link carries its own token, so
  /// this one goes out with no auth headers and works for a visitor who has no
  /// account on this server at all.
  Future<void> enqueuePublicDownload({
    required String token,
    required String name,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    state = <TransferModel>[
      ...state,
      TransferModel(
        id: 'down-$now-share-$token',
        kind: TransferKind.download,
        name: name,
        status: TransferStatus.queued,
        totalBytes: sizeBytes,
        sourceUrl:
            ref.read(apiClientProvider).absolute(Api.publicShareDownload(token)),
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await _persist();
    _schedulePump();
  }

  /// Enqueues an offline copy: a download whose destination is the app's own
  /// offline directory rather than this platform's downloads folder.
  ///
  /// It is the same queue and the same resumable download as everything else,
  /// which is the point. Offline availability is not a second, parallel
  /// download path that has to be kept in step with this one.
  Future<void> enqueueOfflineCopy({
    required String nodeId,
    required String name,
    required int sizeBytes,
    required String destinationPath,
  }) async {
    // a re-mark of something already queued must not stack up duplicates
    final pending = state.any(
      (t) =>
          t.nodeId == nodeId &&
          t.destinationPath == destinationPath &&
          !t.status.isFinished,
    );
    if (pending) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    state = <TransferModel>[
      ...state,
      TransferModel(
        id: 'offline-$now-$nodeId',
        kind: TransferKind.download,
        name: name,
        status: TransferStatus.queued,
        nodeId: nodeId,
        totalBytes: sizeBytes,
        destinationPath: destinationPath,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await _persist();
    _schedulePump();
  }

  Future<void> retry(String id) async {
    final transfer = _byId(id);
    if (transfer == null) return;
    _replace(transfer.copyWith(
      status: TransferStatus.queued,
      attempts: 0,
      nextAttemptAt: 0,
      failureMessage: '',
    ));
    _schedulePump();
  }

  Future<void> retryAll() async {
    state = <TransferModel>[
      for (final transfer in state)
        if (transfer.status == TransferStatus.failed)
          transfer.copyWith(
            status: TransferStatus.queued,
            attempts: 0,
            nextAttemptAt: 0,
            failureMessage: '',
          )
        else
          transfer,
    ];
    await _persist();
    _schedulePump();
  }

  Future<void> cancel(String id) async {
    _cancels.remove(id)?.cancel('cancelled');
    final transfer = _byId(id);
    if (transfer != null && transfer.uploadUrl.isNotEmpty) {
      unawaited(_uploader.terminate(transfer.uploadUrl));
    }
    state = state.where((t) => t.id != id).toList();
    // a cancelled browser upload is still holding its bytes in memory
    InMemorySources.instance.drop(id);
    await _store.remove(id);
  }

  /// Clears what is already done, leaving anything unfinished alone.
  Future<void> clearCompleted() async {
    final gone = state
        .where((transfer) => transfer.status == TransferStatus.completed)
        .map((transfer) => transfer.id)
        .toList();
    state = state
        .where((transfer) => transfer.status != TransferStatus.completed)
        .toList();
    for (final id in gone) {
      InMemorySources.instance.drop(id);
    }
    await _store.removeMany(gone);
  }

  void _pauseAll() {
    for (final token in _cancels.values) {
      token.cancel('offline');
    }
    // ask the OS to wake the app when there is a network again, so these do
    // not sit paused until someone happens to reopen it
    if (PlatformService.hasBackgroundService) {
      unawaited(ref.read(platformServiceProvider).scheduleRetryOnReconnect());
      unawaited(ref.read(platformServiceProvider).endTransfers());
      _serviceRunning = false;
    }
    _cancels.clear();
    state = <TransferModel>[
      for (final transfer in state)
        if (transfer.isActive || transfer.status == TransferStatus.queued)
          transfer.copyWith(status: TransferStatus.paused)
        else
          transfer,
    ];
    unawaited(_persist());
  }

  void _resumeAfterReconnect() {
    state = <TransferModel>[
      for (final transfer in state)
        if (transfer.status == TransferStatus.paused)
          transfer.copyWith(status: TransferStatus.queued)
        else
          transfer,
    ];
    unawaited(_persist());
    _schedulePump();
  }

  void _schedulePump() {
    _pump?.cancel();
    _pump = Timer(const Duration(milliseconds: 120), _pumpQueue);
    _syncBackgroundService();
  }

  /// Keeps the OS's idea of what this app is doing in step with the queue.
  ///
  /// Dart owns the queue and native owns only the notification, so the two can
  /// never disagree about what is happening. On the platforms with nothing to
  /// declare, every call here is a no-op.
  void _syncBackgroundService() {
    if (!PlatformService.hasBackgroundService) return;
    final platform = ref.read(platformServiceProvider);
    final summary = TransferSummary.of(state);

    if (!summary.isBusy && summary.total == 0) {
      unawaited(platform.endTransfers());
      _serviceRunning = false;
      return;
    }
    if (!summary.isBusy) return;

    final active = state.firstWhere(
      (transfer) => transfer.isActive,
      orElse: () => state.first,
    );
    final title = active.kind == TransferKind.download
        ? 'Downloading'
        : 'Uploading';
    final body = summary.active > 1
        ? '${summary.active} files'
        : active.name;

    if (!_serviceRunning) {
      _serviceRunning = true;
      unawaited(platform.beginTransfers(title: title, body: body));
      return;
    }
    unawaited(
      platform.updateTransfers(
        title: title,
        body: body,
        percent: (active.progress * 100).round(),
        indeterminate: active.totalBytes <= 0,
      ),
    );
  }

  /// Starts as many transfers as the concurrency cap allows and no more, so a
  /// bulk upload of hundreds of files goes in waves rather than opening
  /// hundreds of connections at once.
  void _pumpQueue() {
    if (!_online) return;

    // uploads and downloads get their own budget rather than sharing one, so
    // a long download queue cannot starve the photo you just sent
    var uploadSlots = TransferLimits.concurrentUploads -
        state
            .where((t) => t.isActive && t.kind == TransferKind.upload)
            .length;
    var downloadSlots = TransferLimits.concurrentDownloads -
        state
            .where((t) => t.isActive && t.kind == TransferKind.download)
            .length;
    if (uploadSlots <= 0 && downloadSlots <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final transfer in state) {
      if (uploadSlots <= 0 && downloadSlots <= 0) break;
      if (transfer.status != TransferStatus.queued &&
          transfer.status != TransferStatus.retrying) {
        continue;
      }
      if (transfer.nextAttemptAt > now) continue;

      if (transfer.kind == TransferKind.download) {
        if (downloadSlots <= 0) continue;
        downloadSlots--;
      } else {
        if (uploadSlots <= 0) continue;
        uploadSlots--;
      }
      unawaited(_run(transfer.id));
    }
  }

  Future<void> _run(String id) async {
    final kind = _byId(id)?.kind;
    if (kind == TransferKind.download) {
      await _runDownload(id);
      return;
    }
    await _runUpload(id);
  }

  Future<void> _runUpload(String id) async {
    var transfer = _byId(id);
    if (transfer == null) return;

    final cancel = CancelToken();
    _cancels[id] = cancel;
    _replace(transfer.copyWith(status: TransferStatus.inProgress));

    try {
      final source = _sourceFor(transfer);
      if (source == null || !await source.exists()) {
        _fail(id, FailureReason.fileMissing, 'that file is no longer here');
        return;
      }

      var uploadUrl = transfer.uploadUrl;
      if (uploadUrl.isEmpty) {
        uploadUrl = await _uploader.create(
          filename: transfer.name,
          length: transfer.totalBytes,
          parentId: transfer.parentId,
          nodeId: transfer.nodeId,
          mimeType: transfer.mimeType,
        );
        transfer = transfer.copyWith(uploadUrl: uploadUrl);
        _replace(transfer);
      }

      // the server is the authority on how much it already holds
      var offset = await _uploader.offset(uploadUrl);
      _replace(transfer.copyWith(transferredBytes: offset));

      String? nodeId;
      while (offset < transfer.totalBytes) {
        if (cancel.isCancelled) return;
        final result = await _uploader.sendChunk(
          uploadUrl: uploadUrl,
          source: source,
          from: offset,
          chunkSize: tusChunkBytes,
          cancelToken: cancel,
        );
        offset = result.offset;
        nodeId = result.nodeId ?? nodeId;
        final current = _byId(id);
        if (current == null) return;
        _replace(current.copyWith(transferredBytes: offset));
      }

      final done = _byId(id);
      if (done == null) return;
      _replace(done.copyWith(
        status: TransferStatus.completed,
        transferredBytes: transfer.totalBytes,
        nodeId: nodeId ?? done.nodeId,
      ));

      // the server has every byte now, so stop holding a browser upload's
      // copy of them. A few large files would otherwise sit in memory until
      // the tab was closed.
      InMemorySources.instance.drop(id);

      // the folder it landed in refreshes, so it appears without a pull
      ref
          .read(filesControllerProvider.notifier)
          .applyRemoteChange(parentId: transfer.parentId, nodeId: nodeId);
    } on ApiException catch (error) {
      _handleFailure(id, error);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return;
      _handleFailure(
        id,
        const ApiException(
          kind: ApiErrorKind.unreachable,
          message: 'the connection dropped',
        ),
      );
    } on FileSystemException {
      _fail(id, FailureReason.fileMissing, 'that file could not be read');
    } finally {
      _cancels.remove(id);
      _schedulePump();
    }
  }

  /// A download reads the node's bytes into a sink and reports progress as
  /// they arrive.
  ///
  /// Where the platform can resume, it asks for the range after what is
  /// already on disk, so a dropped connection costs the remainder and not the
  /// whole file. A browser tab cannot do that and says so, and this asks for
  /// the whole body there rather than sending a Range header that would
  /// silently produce a truncated file.
  Future<void> _runDownload(String id) async {
    final transfer = _byId(id);
    if (transfer == null) return;

    final cancel = CancelToken();
    _cancels[id] = cancel;
    _replace(transfer.copyWith(status: TransferStatus.inProgress));

    DownloadSink? sink;
    try {
      sink = transfer.destinationPath.isEmpty
          ? await DownloadSink.open(transfer.name)
          : await DownloadSink.openAt(transfer.destinationPath);
      final from = DownloadSink.supportsResume ? sink.resumeAt : 0;

      // already whole before this run even started
      if (transfer.totalBytes > 0 && from >= transfer.totalBytes) {
        final path = await sink.finish();
        sink = null;
        _completeDownload(id, transfer.totalBytes, path);
        return;
      }

      _replace(transfer.copyWith(transferredBytes: from));

      final response = await ref.read(apiClientProvider).raw<ResponseBody>(
            'GET',
            transfer.sourceUrl.isNotEmpty
                ? transfer.sourceUrl
                : Api.download(transfer.nodeId),
            headers: from > 0 ? <String, dynamic>{'Range': 'bytes=$from-'} : null,
            responseType: ResponseType.stream,
            cancelToken: cancel,
          );

      // a server that ignored the Range header restarts the file, so the
      // partial on disk has to go rather than be appended to
      if (from > 0 && response.statusCode != 206) {
        await sink.discard();
        sink = transfer.destinationPath.isEmpty
            ? await DownloadSink.open(transfer.name)
            : await DownloadSink.openAt(transfer.destinationPath);
      }

      var received = from;
      await for (final chunk in response.data!.stream) {
        if (cancel.isCancelled) return;
        await sink.write(chunk);
        received += chunk.length;
        final current = _byId(id);
        if (current == null) return;
        _replace(current.copyWith(transferredBytes: received));
      }

      final path = await sink.finish();
      sink = null;
      _completeDownload(id, received, path);

      // an offline copy has to tell the offline registry it arrived, or the
      // badge stays hollow and the next reconcile downloads it all over again
      if (transfer.destinationPath.isNotEmpty) {
        unawaited(_recordOfflineCopy(transfer, path, received));
      }
    } on ApiException catch (error) {
      await sink?.close();
      _handleFailure(id, error);
    } on DioException catch (error) {
      await sink?.close();
      if (CancelToken.isCancel(error)) return;
      _handleFailure(
        id,
        const ApiException(
          kind: ApiErrorKind.unreachable,
          message: 'the connection dropped',
        ),
      );
    } on FileSystemException {
      await sink?.close();
      _fail(id, FailureReason.fileMissing, 'that file could not be written');
    } finally {
      _cancels.remove(id);
      _schedulePump();
    }
  }

  /// Reads the node's current checksum and hands it to the offline registry,
  /// which is what a later reconcile compares against to decide whether this
  /// copy is still the file the server holds.
  Future<void> _recordOfflineCopy(
    TransferModel transfer,
    String path,
    int bytes,
  ) async {
    try {
      final node = await ref.read(filesDbProvider).node(transfer.nodeId);
      await ref.read(offlineControllerProvider.notifier).onDownloaded(
            nodeId: transfer.nodeId,
            path: path,
            checksum: node.checksum,
            sizeBytes: bytes,
          );
    } on Object {
      // the bytes are on disk either way. Without a checksum the next
      // reconcile simply re-downloads, which is correct, only wasteful
    }
  }

  void _completeDownload(String id, int bytes, String savedTo) {
    final done = _byId(id);
    if (done == null) return;
    _replace(done.copyWith(
      status: TransferStatus.completed,
      transferredBytes: bytes,
      totalBytes: done.totalBytes > 0 ? done.totalBytes : bytes,
      savedTo: savedTo,
    ));
  }

  /// Something plausibly transient keeps retrying with backoff. Something that
  /// will never succeed on its own fails immediately with its real reason.
  void _handleFailure(String id, ApiException error) {
    final transfer = _byId(id);
    if (transfer == null) return;

    final reason = switch (error.kind) {
      ApiErrorKind.unauthorized => FailureReason.sessionExpired,
      ApiErrorKind.forbidden => FailureReason.permission,
      ApiErrorKind.quota => FailureReason.quota,
      ApiErrorKind.notFound => FailureReason.notFound,
      ApiErrorKind.offline || ApiErrorKind.unreachable || ApiErrorKind.timeout =>
        FailureReason.network,
      ApiErrorKind.server || ApiErrorKind.rateLimited => FailureReason.server,
      _ => FailureReason.unknown,
    };

    if (!reason.isTransient) {
      _fail(id, reason, error.message);
      return;
    }

    // exponential backoff with jitter, capped around a minute
    final attempts = transfer.attempts + 1;
    final base = AppDurations.retryBase.inMilliseconds * (1 << math.min(attempts, 6));
    final capped = math.min(base, AppDurations.retryMax.inMilliseconds);
    final jitter = math.Random().nextInt(math.max(1, capped ~/ 4));

    _replace(transfer.copyWith(
      status: TransferStatus.retrying,
      attempts: attempts,
      nextAttemptAt: DateTime.now().millisecondsSinceEpoch + capped + jitter,
      failureReason: reason,
      failureMessage: error.message,
    ));

    // a retrying item wakes itself up rather than waiting for another event
    Timer(Duration(milliseconds: capped + jitter), _pumpQueue);
  }

  void _fail(String id, FailureReason reason, String message) {
    final transfer = _byId(id);
    if (transfer == null) return;
    _replace(transfer.copyWith(
      status: TransferStatus.failed,
      failureReason: reason,
      failureMessage: message,
    ));
  }
}

final transferControllerProvider =
    NotifierProvider<TransferController, List<TransferModel>>(
  TransferController.new,
);

/// The aggregate the uploads tray shows, narrow enough that the tray rebuilds
/// without dragging the rest of the screen with it.
final transferSummaryProvider = Provider<TransferSummary>((ref) {
  return TransferSummary.of(ref.watch(transferControllerProvider));
});
