import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/core/db/local_db.dart';
import 'package:localdrive/core/enums/file_category.dart';
import 'package:localdrive/core/enums/transfer_status.dart';
import 'package:localdrive/features/files/db/node_cache.dart';
import 'package:localdrive/features/files/models/node_model.dart';
import 'package:localdrive/features/upload/models/transfer_model.dart';

NodeModel _node(
  String id, {
  String name = 'file.txt',
  String parentId = 'root',
  bool isFolder = false,
  String checksum = 'abc',
  int size = 10,
}) =>
    NodeModel(
      id: id,
      name: name,
      isFolder: isFolder,
      category: isFolder ? FileCategory.folder : FileCategory.text,
      libraryId: 'lib',
      parentId: parentId,
      checksum: checksum,
      sizeBytes: size,
      starred: true,
      role: AccessRole.owner,
      updatedAt: 1700000000000,
    );

void main() {
  late LocalDb db;

  setUp(() => db = LocalDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('the metadata cache', () {
    test('a cached node round trips with every field intact', () async {
      final cache = NodeCache(db);
      await cache.write('root', <NodeModel>[_node('n1', name: 'notes.txt')]);

      final read = await cache.readOne('n1');
      expect(read, isNotNull);
      expect(read!.name, 'notes.txt');
      expect(read.checksum, 'abc');
      expect(read.libraryId, 'lib');
      // the fields a stripped down cache would quietly lose
      expect(read.starred, isTrue);
      expect(read.role, AccessRole.owner);
      expect(read.category, FileCategory.text);
    });

    test('rewriting a folder drops what is no longer in it', () async {
      final cache = NodeCache(db);
      await cache.write('root', <NodeModel>[_node('n1'), _node('n2')]);
      expect((await cache.read('root')).length, 2);

      // n2 was deleted on another device
      await cache.write('root', <NodeModel>[_node('n1')]);

      final remaining = await cache.read('root');
      expect(remaining.map((n) => n.id), <String>['n1']);
      expect(await cache.readOne('n2'), isNull);
    });

    test('one unreadable row does not take the folder with it', () async {
      await db.cacheNode(
        CachedNodesCompanion.insert(
          id: 'broken',
          parentId: const Value('root'),
          name: 'broken',
          payload: 'this is not json',
          cachedAt: 1,
        ),
      );
      await NodeCache(db).write('root', <NodeModel>[]);
      await db.cacheNode(
        CachedNodesCompanion.insert(
          id: 'broken',
          parentId: const Value('root'),
          name: 'broken',
          payload: 'this is not json',
          cachedAt: 1,
        ),
      );
      await NodeCache(db).writeOne(_node('good'));

      final rows = await NodeCache(db).read('root');
      expect(rows.map((n) => n.id), <String>['good']);
    });

    test('folders sort ahead of files, then by name', () async {
      final cache = NodeCache(db);
      await cache.write('root', <NodeModel>[
        _node('f1', name: 'zebra.txt'),
        _node('d1', name: 'photos', isFolder: true),
        _node('f2', name: 'apple.txt'),
      ]);

      final rows = await cache.read('root');
      expect(rows.map((n) => n.name), <String>['photos', 'apple.txt', 'zebra.txt']);
    });
  });

  group('offline availability', () {
    test('unmarking a folder keeps what was chosen individually', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.markOffline(
        OfflineItemsCompanion.insert(nodeId: 'inherited', markedAt: now),
      );
      await db.markOffline(
        OfflineItemsCompanion.insert(
          nodeId: 'inherited',
          explicit: const Value(false),
          markedAt: now,
        ),
      );
      await db.markOffline(
        OfflineItemsCompanion.insert(
          nodeId: 'chosen',
          explicit: const Value(true),
          markedAt: now,
        ),
      );

      await db.unmarkInherited(<String>{'inherited', 'chosen'});

      final left = await db.allOfflineItems();
      expect(left.map((row) => row.nodeId), <String>['chosen']);
    });

    test('only files that actually landed count toward the total', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.markOffline(
        OfflineItemsCompanion.insert(
          nodeId: 'arrived',
          localPath: const Value('/tmp/arrived'),
          sizeBytes: const Value(500),
          markedAt: now,
        ),
      );
      // still downloading, so it has no path yet and costs nothing on disk
      await db.markOffline(
        OfflineItemsCompanion.insert(
          nodeId: 'pending',
          sizeBytes: const Value(9000),
          markedAt: now,
        ),
      );

      expect(await db.offlineBytes(), 500);
    });
  });

  group('the durable transfer queue', () {
    test('a progress update rewrites one row, not the queue', () async {
      final a = TransferModel(
        id: 'a',
        kind: TransferKind.upload,
        name: 'a.bin',
        status: TransferStatus.queued,
        totalBytes: 100,
      );
      final b = TransferModel(
        id: 'b',
        kind: TransferKind.download,
        name: 'b.bin',
        status: TransferStatus.queued,
        totalBytes: 200,
      );

      await db.replaceQueue(<QueuedTransfersCompanion>[
        _row(a),
        _row(b),
      ]);
      await db.upsertTransfer(
        _row(a.copyWith(
          status: TransferStatus.inProgress,
          transferredBytes: 40,
        )),
      );

      final rows = await db.loadQueue();
      expect(rows.length, 2);
      final moved = rows.firstWhere((row) => row.id == 'a');
      expect(moved.transferredBytes, 40);
      expect(moved.status, 'inProgress');
      // the untouched one is exactly as it was
      expect(rows.firstWhere((row) => row.id == 'b').totalBytes, 200);
    });

    test('an offline copy keeps the destination it was queued with', () async {
      const transfer = TransferModel(
        id: 'offline-1',
        kind: TransferKind.download,
        name: 'song.mp3',
        status: TransferStatus.queued,
        nodeId: 'n9',
        destinationPath: '/data/offline/n9.mp3',
      );
      await db.upsertTransfer(_row(transfer));

      final row = (await db.loadQueue()).single;
      expect(row.destinationPath, '/data/offline/n9.mp3');
      expect(row.kind, 'download');
    });
  });

  test('wiping clears every device local table at once', () async {
    await NodeCache(db).write('root', <NodeModel>[_node('n1')]);
    await db.markOffline(
      OfflineItemsCompanion.insert(nodeId: 'n1', markedAt: 1),
    );
    await db.upsertTransfer(
      _row(const TransferModel(
        id: 't1',
        kind: TransferKind.upload,
        name: 'x',
        status: TransferStatus.queued,
      )),
    );

    await db.wipe();

    expect(await db.cachedChildren('root'), isEmpty);
    expect(await db.allOfflineItems(), isEmpty);
    expect(await db.loadQueue(), isEmpty);
  });
}

QueuedTransfersCompanion _row(TransferModel t) =>
    QueuedTransfersCompanion.insert(
      id: t.id,
      kind: t.kind.name,
      name: t.name,
      status: t.status.name,
      nodeId: Value(t.nodeId),
      totalBytes: Value(t.totalBytes),
      transferredBytes: Value(t.transferredBytes),
      destinationPath: Value(t.destinationPath),
      createdAt: Value(t.createdAt),
    );
