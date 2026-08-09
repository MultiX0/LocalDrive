import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/db/local_db.dart';
import '../models/node_model.dart';

/// The metadata cache: what each folder looked like the last time this device
/// saw it.
///
/// It makes a folder render instantly on reopen and what keeps the
/// tree browsable with no connection at all. It says nothing about whether a
/// file's bytes are on the device, which is a separate promise made by the
/// offline registry.
class NodeCache {
  const NodeCache(this._db);

  final LocalDb _db;

  /// Replaces one folder's cached contents.
  ///
  /// The whole folder, not row by row, because a file deleted on another
  /// device has to disappear here too and an upsert would leave it behind.
  Future<void> write(String parentId, List<NodeModel> nodes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.cacheFolder(parentId, <CachedNodesCompanion>[
      for (final node in nodes) _toRow(node, parentId, now),
    ]);
  }

  Future<void> writeOne(NodeModel node) => _db.cacheNode(
        _toRow(node, node.parentId, DateTime.now().millisecondsSinceEpoch),
      );

  Future<List<NodeModel>> read(String parentId) async {
    final rows = await _db.cachedChildren(parentId);
    return <NodeModel>[
      for (final row in rows) ...<NodeModel>[
        if (_fromRow(row) case final NodeModel node) node,
      ],
    ];
  }

  Future<NodeModel?> readOne(String id) async {
    final row = await _db.cachedNode(id);
    return row == null ? null : _fromRow(row);
  }

  Future<void> forget(String id) => _db.forgetNode(id);

  static CachedNodesCompanion _toRow(NodeModel node, String parentId, int now) =>
      CachedNodesCompanion.insert(
        id: node.id,
        parentId: Value(parentId),
        libraryId: Value(node.libraryId),
        name: node.name,
        isFolder: Value(node.isFolder),
        category: Value(node.category.name),
        sizeBytes: Value(node.sizeBytes),
        checksum: Value(node.checksum),
        updatedAt: Value(node.updatedAt),
        // the whole server payload, so a cached tile renders with every field
        // the live one has rather than a stripped down version of itself
        payload: jsonEncode(node.toJson()),
        cachedAt: now,
      );

  static NodeModel? _fromRow(CachedNode row) {
    try {
      final decoded = jsonDecode(row.payload);
      if (decoded is! Map<String, dynamic>) return null;
      return NodeModel.fromJson(decoded);
    } on FormatException {
      // one unreadable row must not take the whole folder down with it
      return null;
    }
  }
}
