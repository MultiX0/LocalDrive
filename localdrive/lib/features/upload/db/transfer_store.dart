import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/local_db.dart';
import '../../../core/enums/transfer_status.dart';
import '../models/transfer_model.dart';

/// Durable storage for the transfer queue.
///
/// The queue is written here before any network call starts, and the UI reads
/// the same records the transfer engine works from, so progress shown in the
/// app is never out of sync with what is actually happening.
///
/// It is backed by the device database rather than a JSON file. Progress
/// updates land many times a second per transfer, and rewriting the whole
/// queue for each one does not scale past a handful of items. A row update
/// touches only the row that changed.
class TransferStore {
  TransferStore(this._db);

  final LocalDb _db;

  Future<List<TransferModel>> load() async {
    try {
      final rows = await _db.loadQueue();
      final restored = rows.map(_toModel).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // an older build kept the queue in a JSON file beside the database. If
      // one is still there, it is imported once and removed, so upgrading does
      // not silently drop whatever was mid flight at the time
      if (restored.isEmpty) {
        final legacy = await _importLegacyFile();
        if (legacy.isNotEmpty) {
          await save(legacy);
          return legacy;
        }
      }
      return restored;
    } on Object {
      // a corrupt queue is not worth blocking startup for; the transfers are
      // recoverable by re-adding them, the app is not recoverable if it will
      // not open
      return <TransferModel>[];
    }
  }

  Future<void> save(List<TransferModel> transfers) async {
    try {
      await _db.replaceQueue(transfers.map(_toRow).toList());
    } on Object {
      // losing one persist is survivable; the in memory queue keeps running
    }
  }

  /// The hot path: one transfer moved, so only that row is written.
  Future<void> upsert(TransferModel transfer) async {
    try {
      await _db.upsertTransfer(_toRow(transfer));
    } on Object {
      // as above, a dropped progress write costs nothing that matters
    }
  }

  Future<void> remove(String id) => _db.removeTransfer(id);

  Future<void> removeMany(Iterable<String> ids) => _db.removeTransfers(ids);

  Future<void> clear() => _db.replaceQueue(const <QueuedTransfersCompanion>[]);

  static QueuedTransfersCompanion _toRow(TransferModel t) =>
      QueuedTransfersCompanion.insert(
        id: t.id,
        kind: t.kind.name,
        name: t.name,
        status: t.status.name,
        localPath: Value(t.localPath),
        parentId: Value(t.parentId),
        nodeId: Value(t.nodeId),
        mimeType: Value(t.mimeType),
        totalBytes: Value(t.totalBytes),
        transferredBytes: Value(t.transferredBytes),
        uploadUrl: Value(t.uploadUrl),
        sourceUrl: Value(t.sourceUrl),
        destinationPath: Value(t.destinationPath),
        savedTo: Value(t.savedTo),
        attempts: Value(t.attempts),
        nextAttemptAt: Value(t.nextAttemptAt),
        failureReason: Value(t.failureReason.name),
        failureMessage: Value(t.failureMessage),
        createdAt: Value(t.createdAt),
        updatedAt: Value(t.updatedAt),
      );

  static TransferModel _toModel(QueuedTransfer row) => TransferModel(
        id: row.id,
        kind: TransferKind.fromName(row.kind),
        name: row.name,
        status: TransferStatus.fromName(row.status),
        localPath: row.localPath,
        parentId: row.parentId,
        nodeId: row.nodeId,
        mimeType: row.mimeType,
        totalBytes: row.totalBytes,
        transferredBytes: row.transferredBytes,
        uploadUrl: row.uploadUrl,
        sourceUrl: row.sourceUrl,
        destinationPath: row.destinationPath,
        savedTo: row.savedTo,
        attempts: row.attempts,
        nextAttemptAt: row.nextAttemptAt,
        failureReason: FailureReason.fromName(row.failureReason),
        failureMessage: row.failureMessage,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  /// One time import of the JSON queue an earlier build wrote. Deleted once
  /// read, so this costs a single missing file check on every later launch.
  Future<List<TransferModel>> _importLegacyFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'transfer_queue.json'));
      if (!await file.exists()) return const <TransferModel>[];

      final raw = await file.readAsString();
      await file.delete();
      if (raw.trim().isEmpty) return const <TransferModel>[];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <TransferModel>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TransferModel.fromJson)
          .toList();
    } on Object {
      return const <TransferModel>[];
    }
  }
}
