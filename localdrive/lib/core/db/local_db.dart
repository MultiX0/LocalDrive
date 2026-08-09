import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_db.g.dart';

/// What a folder looked like the last time this device saw it.
///
/// This is a cache, not a source of truth. It exists so a folder renders
/// instantly on reopen and so the tree is still browsable with no connection.
/// It says nothing about whether the file's actual bytes are on the device,
/// which is what [OfflineItems] is for.
class CachedNodes extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().withDefault(const Constant(''))();
  TextColumn get libraryId => text().withDefault(const Constant(''))();
  TextColumn get name => text()();
  BoolColumn get isFolder => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant('generic'))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get checksum => text().withDefault(const Constant(''))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  /// the full server payload, so a cached tile renders with every field the
  /// live one has rather than a stripped down version of itself
  TextColumn get payload => text()();

  /// when this row was written, which is what an eviction pass sorts by
  IntColumn get cachedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// One item this device has been told to keep available offline.
///
/// Device local by design: the same file can be offline on a phone and not on
/// its owner's tablet, so this never leaves the device and is never sent to
/// the server. A folder row is a live preference, not a snapshot, which is why
/// `isFolder` matters here: anything added to that folder later gets pulled
/// down too, until the person turns it back off.
class OfflineItems extends Table {
  TextColumn get nodeId => text()();
  BoolColumn get isFolder => boolean().withDefault(const Constant(false))();

  /// true when the person chose this item themselves, false when it is only
  /// here because a folder above it is marked. Unmarking the folder clears the
  /// inherited rows and leaves the explicit ones alone.
  BoolColumn get explicit => boolean().withDefault(const Constant(true))();
  TextColumn get name => text().withDefault(const Constant(''))();

  /// where the bytes actually are, empty until the download finishes
  TextColumn get localPath => text().withDefault(const Constant(''))();

  /// the checksum of what is on disk. Comparing this against the server's
  /// `checksum_sha256` makes a reconnect re-download only what changed
  TextColumn get checksum => text().withDefault(const Constant(''))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get markedAt => integer()();
  IntColumn get syncedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{nodeId};
}

/// The durable transfer queue.
///
/// An item is written here the moment it is enqueued, before any byte moves,
/// so killing the app a second later loses nothing. Drift rather than a JSON
/// file because progress updates land many times a second per transfer and
/// rewriting the whole queue for each one does not scale past a handful.
class QueuedTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get status => text()();
  TextColumn get localPath => text().withDefault(const Constant(''))();
  TextColumn get parentId => text().withDefault(const Constant(''))();
  TextColumn get nodeId => text().withDefault(const Constant(''))();
  TextColumn get mimeType => text().withDefault(const Constant(''))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get transferredBytes => integer().withDefault(const Constant(0))();
  TextColumn get uploadUrl => text().withDefault(const Constant(''))();
  TextColumn get sourceUrl => text().withDefault(const Constant(''))();
  TextColumn get destinationPath => text().withDefault(const Constant(''))();
  TextColumn get savedTo => text().withDefault(const Constant(''))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().withDefault(const Constant(0))();
  TextColumn get failureReason =>
      text().withDefault(const Constant('unknown'))();
  TextColumn get failureMessage => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The device local database: the metadata cache, the offline registry, and
/// the transfer queue.
///
/// One database rather than three, because all three are per device state with
/// the same lifetime, and a single file is one thing to open, one thing to
/// migrate, and one thing to wipe on sign out.
@DriftDatabase(tables: <Type>[CachedNodes, OfflineItems, QueuedTransfers])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'localdrive', web: _web));

  /// Where the browser build finds its database engine.
  ///
  /// On web there is no SQLite on the machine, so drift runs it as WebAssembly
  /// inside a worker. Both files ship in `web/` and are served from the app's
  /// own origin. Without this the constructor throws the moment anything reads
  /// the database, which on this app is the first folder listing, and the
  /// screen shows a generic failure with no clue as to the cause.
  static final DriftWebOptions _web = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  @override
  int get schemaVersion => 1;

  // the metadata cache

  /// Replaces one folder's cached contents wholesale.
  ///
  /// Wholesale rather than upsert-per-row, because a file deleted on another
  /// device has to disappear here too, and an upsert would leave it behind
  /// forever.
  Future<void> cacheFolder(
    String parentId,
    List<CachedNodesCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(cachedNodes)..where((t) => t.parentId.equals(parentId)))
          .go();
      await batch((b) => b.insertAll(cachedNodes, rows));
    });
  }

  Future<void> cacheNode(CachedNodesCompanion row) =>
      into(cachedNodes).insertOnConflictUpdate(row);

  Future<List<CachedNode>> cachedChildren(String parentId) =>
      (select(cachedNodes)
            ..where((t) => t.parentId.equals(parentId))
            ..orderBy(<OrderClauseGenerator<$CachedNodesTable>>[
              (t) => OrderingTerm(expression: t.isFolder, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .get();

  Future<CachedNode?> cachedNode(String id) =>
      (select(cachedNodes)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> forgetNode(String id) =>
      (delete(cachedNodes)..where((t) => t.id.equals(id))).go();

  // offline availability

  Future<List<OfflineItem>> allOfflineItems() => select(offlineItems).get();

  Future<OfflineItem?> offlineItem(String nodeId) =>
      (select(offlineItems)..where((t) => t.nodeId.equals(nodeId)))
          .getSingleOrNull();

  Stream<List<OfflineItem>> watchOfflineItems() => select(offlineItems).watch();

  Future<void> markOffline(OfflineItemsCompanion row) =>
      into(offlineItems).insertOnConflictUpdate(row);

  Future<void> unmarkOffline(String nodeId) =>
      (delete(offlineItems)..where((t) => t.nodeId.equals(nodeId))).go();

  /// Drops every row that is only present because [folderId] was marked. The
  /// explicit ones survive, since the person chose those individually.
  Future<void> unmarkInherited(Set<String> nodeIds) async {
    if (nodeIds.isEmpty) return;
    await (delete(offlineItems)
          ..where((t) => t.nodeId.isIn(nodeIds) & t.explicit.equals(false)))
        .go();
  }

  /// What offline content is costing on this device, in bytes.
  Future<int> offlineBytes() async {
    final total = offlineItems.sizeBytes.sum();
    final row = await (selectOnly(offlineItems)
          ..addColumns(<Expression<Object>>[total])
          ..where(offlineItems.localPath.equals('').not()))
        .getSingleOrNull();
    return row?.read(total) ?? 0;
  }

  // the transfer queue

  Future<List<QueuedTransfer>> loadQueue() => select(queuedTransfers).get();

  Future<void> upsertTransfer(QueuedTransfersCompanion row) =>
      into(queuedTransfers).insertOnConflictUpdate(row);

  Future<void> replaceQueue(List<QueuedTransfersCompanion> rows) async {
    await transaction(() async {
      await delete(queuedTransfers).go();
      await batch((b) => b.insertAll(queuedTransfers, rows));
    });
  }

  Future<void> removeTransfer(String id) =>
      (delete(queuedTransfers)..where((t) => t.id.equals(id))).go();

  Future<void> removeTransfers(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(queuedTransfers)..where((t) => t.id.isIn(ids))).go();
  }

  /// Everything device local, gone. This runs on sign out, because the next
  /// person to use this device has no business seeing the previous one's
  /// folder names, let alone their files.
  Future<void> wipe() async {
    await transaction(() async {
      await delete(cachedNodes).go();
      await delete(offlineItems).go();
      await delete(queuedTransfers).go();
    });
  }
}
