import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/db/local_db.dart';
import '../../../core/services/core_providers.dart';
import '../../files/models/node_model.dart';
import '../../files/providers/files_providers.dart';
import '../../upload/controller/transfer_controller.dart';
import '../db/offline_files.dart';

final offlineFilesProvider = Provider<OfflineFiles>((ref) => OfflineFiles());

/// Everything this device is keeping offline, keyed by node id.
///
/// It watches the table rather than reloading, so a download finishing updates
/// every badge on screen without anything having to remember to refresh.
final offlineIndexProvider = StreamProvider<Map<String, OfflineItem>>((ref) {
  return ref.watch(localDbProvider).watchOfflineItems().map(
        (rows) => <String, OfflineItem>{
          for (final row in rows) row.nodeId: row,
        },
      );
});

/// The local path for one node's bytes, or empty when it is not kept on this
/// device. A preview screen checks this before reaching for the network.
final offlineLocalPathProvider =
    FutureProvider.autoDispose.family<String, String>((ref, nodeId) {
  ref.watch(offlineIndexProvider);
  return ref.read(offlineControllerProvider.notifier).localPath(nodeId);
});

/// Whether one node is marked, for a tile badge or a menu entry.
final isOfflineProvider = Provider.family<bool, String>((ref, nodeId) {
  return ref.watch(offlineIndexProvider).maybeWhen(
        data: (index) => index.containsKey(nodeId),
        orElse: () => false,
      );
});

/// How much space offline content is using on this device.
final offlineUsageProvider = FutureProvider<OfflineUsage>((ref) async {
  // rebuilds whenever the table changes, so the settings panel is live
  ref.watch(offlineIndexProvider);
  return ref.read(offlineControllerProvider.notifier).usage();
});

/// Total bytes and the per folder breakdown the settings panel shows.
class OfflineUsage {
  const OfflineUsage({
    required this.totalBytes,
    required this.onDiskBytes,
    required this.fileCount,
    required this.byFolder,
    required this.softCapBytes,
  });

  final int totalBytes;

  /// what the directory actually weighs, which can differ from [totalBytes]
  /// if the OS reclaimed space or a download has not finished yet
  final int onDiskBytes;
  final int fileCount;

  /// name to bytes, largest first, for the breakdown list
  final List<({String name, int bytes, String nodeId})> byFolder;
  final int softCapBytes;

  bool get overCap => softCapBytes > 0 && totalBytes > softCapBytes;

  double get capFraction =>
      softCapBytes <= 0 ? 0 : (totalBytes / softCapBytes).clamp(0.0, 1.0);

  static const OfflineUsage empty = OfflineUsage(
    totalBytes: 0,
    onDiskBytes: 0,
    fileCount: 0,
    byFolder: <({String name, int bytes, String nodeId})>[],
    softCapBytes: TransferLimits.defaultOfflineSoftCapBytes,
  );
}

/// Offline availability: mark a file or folder, and it opens from this device
/// with no connection at all.
///
/// This is a device-local decision and never server state. The same file can
/// be offline on a phone and not on its owner's tablet, which is why none of
/// it is sent anywhere.
class OfflineController extends Notifier<void> {
  LocalDb get _db => ref.read(localDbProvider);
  OfflineFiles get _files => ref.read(offlineFilesProvider);

  @override
  void build() {
    // on reconnect, compare what is on disk against what the server holds and
    // pull only what actually changed. Never a blind re-fetch of everything
    ref.listen(reconnectedProvider, (previous, next) {
      next.whenData((_) => unawaited(reconcile()));
    });
  }

  /// Whether this platform can keep files offline at all. A browser tab has no
  /// filesystem, so the option is not offered there rather than offered and
  /// then failing.
  static bool get isSupported => !kIsWeb;

  Future<bool> isMarked(String nodeId) async =>
      await _db.offlineItem(nodeId) != null;

  /// Marks a node. A folder cascades to its current contents and stays a live
  /// preference: anything added to it later is pulled down on the next
  /// reconcile, until the person turns it back off.
  Future<void> mark(NodeModel node) async {
    if (!isSupported) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.markOffline(
      OfflineItemsCompanion.insert(
        nodeId: node.id,
        isFolder: Value(node.isFolder),
        explicit: const Value(true),
        name: Value(node.name),
        sizeBytes: Value(node.sizeBytes),
        markedAt: now,
      ),
    );

    if (node.isFolder) {
      await _cascade(node.id, now);
    } else {
      await _fetch(node);
    }
  }

  /// Unmarks a node and deletes its bytes. A folder takes its inherited
  /// children with it and leaves anything separately marked alone.
  Future<void> unmark(NodeModel node) async {
    final row = await _db.offlineItem(node.id);
    if (row != null) await _files.remove(row.localPath);
    await _db.unmarkOffline(node.id);

    if (!node.isFolder) return;

    final children = await _descendantIds(node.id);
    for (final id in children) {
      final child = await _db.offlineItem(id);
      if (child == null || child.explicit) continue;
      await _files.remove(child.localPath);
    }
    await _db.unmarkInherited(children);
  }

  /// Brings every marked item up to date.
  ///
  /// It compares the local checksum against the server's `checksum_sha256` and
  /// only re-downloads what changed, reusing the same durable transfer queue
  /// as everything else rather than being a second, different download path.
  Future<void> reconcile() async {
    if (!isSupported) return;
    final rows = await _db.allOfflineItems();
    if (rows.isEmpty) return;

    final db = ref.read(filesDbProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final row in rows) {
      NodeModel node;
      try {
        node = await db.node(row.nodeId);
      } on Object {
        // gone from the server, or no longer visible to this account. The
        // local copy goes with it rather than lingering as a private fork
        await _files.remove(row.localPath);
        await _db.unmarkOffline(row.nodeId);
        continue;
      }

      if (node.isFolder) {
        await _cascade(node.id, now);
        continue;
      }

      final present = await _files.exists(row.localPath);
      final current = present && row.checksum == node.checksum;
      if (current) continue;

      await _fetch(node, explicit: row.explicit);
    }
  }

  /// Records that a download finished, which is what turns the badge solid.
  Future<void> onDownloaded({
    required String nodeId,
    required String path,
    required String checksum,
    required int sizeBytes,
  }) async {
    final row = await _db.offlineItem(nodeId);
    if (row == null) return;
    await _db.markOffline(
      OfflineItemsCompanion.insert(
        nodeId: nodeId,
        isFolder: Value(row.isFolder),
        explicit: Value(row.explicit),
        name: Value(row.name),
        localPath: Value(path),
        checksum: Value(checksum),
        sizeBytes: Value(sizeBytes),
        markedAt: row.markedAt,
        syncedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// The local path for a node, or empty if it is not available offline. This
  /// is what a preview screen checks before reaching for the network.
  Future<String> localPath(String nodeId) async {
    final row = await _db.offlineItem(nodeId);
    if (row == null || row.localPath.isEmpty) return '';
    return await _files.exists(row.localPath) ? row.localPath : '';
  }

  Future<OfflineUsage> usage() async {
    final rows = await _db.allOfflineItems();
    final files = rows.where((row) => !row.isFolder).toList();

    final folders = <String, ({String name, int bytes, String nodeId})>{};
    for (final row in rows.where((row) => row.isFolder)) {
      folders[row.nodeId] = (name: row.name, bytes: 0, nodeId: row.nodeId);
    }

    // a file's bytes are attributed to the marked folder it came from, and to
    // a "chosen individually" bucket when it was marked on its own
    var loose = 0;
    for (final file in files) {
      final cached = await _db.cachedNode(file.nodeId);
      final parent = cached?.parentId ?? '';
      final folder = folders[parent];
      if (folder == null) {
        loose += file.sizeBytes;
        continue;
      }
      folders[parent] = (
        name: folder.name,
        bytes: folder.bytes + file.sizeBytes,
        nodeId: folder.nodeId,
      );
    }

    final breakdown = folders.values.where((f) => f.bytes > 0).toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
    if (loose > 0) {
      breakdown.add((name: '', bytes: loose, nodeId: ''));
    }

    final total = files.fold<int>(0, (sum, row) => sum + row.sizeBytes);
    return OfflineUsage(
      totalBytes: total,
      onDiskBytes: await _files.bytesOnDisk(),
      fileCount: files.length,
      byFolder: breakdown,
      softCapBytes: await softCap(),
    );
  }

  /// The configured warning threshold. It warns rather than blocks, because
  /// refusing to keep a file someone asked for is worse than telling them what
  /// it will cost.
  Future<int> softCap() async {
    final raw = await ref
        .read(secureStoreProvider)
        .readString(StorageKeys.offlineSoftCapBytes);
    return int.tryParse(raw ?? '') ??
        TransferLimits.defaultOfflineSoftCapBytes;
  }

  Future<void> setSoftCap(int bytes) async {
    await ref
        .read(secureStoreProvider)
        .writeString(StorageKeys.offlineSoftCapBytes, '$bytes');
    ref.invalidate(offlineUsageProvider);
  }

  /// Removes every offline copy. The marks go too, since keeping them would
  /// only mean the next reconnect downloads it all again.
  Future<void> clearAll() async {
    await _files.clear();
    for (final row in await _db.allOfflineItems()) {
      await _db.unmarkOffline(row.nodeId);
    }
  }

  Future<void> _cascade(String folderId, int now) async {
    final children = await ref.read(filesDbProvider).list(parentId: folderId);
    for (final child in children) {
      final existing = await _db.offlineItem(child.id);
      await _db.markOffline(
        OfflineItemsCompanion.insert(
          nodeId: child.id,
          isFolder: Value(child.isFolder),
          // inherited unless it was already chosen on its own
          explicit: Value(existing?.explicit ?? false),
          name: Value(child.name),
          localPath: Value(existing?.localPath ?? ''),
          checksum: Value(existing?.checksum ?? ''),
          sizeBytes: Value(child.sizeBytes),
          markedAt: existing?.markedAt ?? now,
          syncedAt: Value(existing?.syncedAt ?? 0),
        ),
      );

      if (child.isFolder) {
        await _cascade(child.id, now);
        continue;
      }

      final present = await _files.exists(existing?.localPath ?? '');
      if (present && existing?.checksum == child.checksum) continue;
      await _fetch(child, explicit: existing?.explicit ?? false);
    }
  }

  Future<void> _fetch(NodeModel node, {bool explicit = true}) async {
    final path = await _files.pathFor(node.id, node.name);
    await ref.read(transferControllerProvider.notifier).enqueueOfflineCopy(
          nodeId: node.id,
          name: node.name,
          sizeBytes: node.sizeBytes,
          destinationPath: path,
        );
  }

  /// Everything below a folder that this device already knows about, from the
  /// metadata cache rather than the network, since unmarking has to work with
  /// no connection.
  Future<Set<String>> _descendantIds(String folderId) async {
    final found = <String>{};
    final queue = <String>[folderId];
    while (queue.isNotEmpty) {
      final parent = queue.removeLast();
      for (final child in await _db.cachedChildren(parent)) {
        if (!found.add(child.id)) continue;
        if (child.isFolder) queue.add(child.id);
      }
    }
    return found;
  }
}

final offlineControllerProvider =
    NotifierProvider<OfflineController, void>(OfflineController.new);
