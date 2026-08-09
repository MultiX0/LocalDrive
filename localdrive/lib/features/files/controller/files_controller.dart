import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_exception.dart';
import '../db/files_db.dart';
import '../models/node_model.dart';
import '../providers/files_providers.dart';

/// Commands against the node tree. Pages call these and never touch the db
/// class directly; every one refreshes exactly the listings it invalidated.
class FilesController extends Notifier<void> {
  @override
  void build() {}

  FilesDb get _db => ref.read(filesDbProvider);

  /// Refreshes one folder and, when it is not the top level, its parent too,
  /// so a breadcrumb count stays honest.
  void _invalidate({String? parentId, String? filter}) {
    ref.invalidate(folderProvider(FolderQuery(parentId: parentId ?? '')));
    if (parentId != null && parentId.isNotEmpty && parentId != Api.rootParent) {
      ref.invalidate(nodeProvider(parentId));
      ref.invalidate(folderPreviewProvider(parentId));
    }
    if (filter != null) {
      ref.invalidate(folderProvider(FolderQuery(filter: filter)));
    }
  }

  Future<NodeModel> createFolder({
    required String name,
    String parentId = '',
    String libraryId = '',
    String color = '',
  }) async {
    // a retry after a lost response replays the first result rather than
    // making a second folder nobody asked for
    final key = 'folder-${DateTime.now().microsecondsSinceEpoch}';
    final node = await _db.createFolder(
      name: name,
      parentId: parentId,
      libraryId: libraryId,
      color: color,
      idempotencyKey: key,
    );
    _invalidate(parentId: parentId);
    return node;
  }

  Future<NodeModel> rename(NodeModel node, String name) async {
    final updated = await _db.rename(node.id, name);
    _invalidate(parentId: node.parentId);
    ref.invalidate(nodeProvider(node.id));
    return updated;
  }

  Future<NodeModel> move(NodeModel node, String newParentId) async {
    final updated = await _db.move(node.id, newParentId);
    _invalidate(parentId: node.parentId);
    _invalidate(parentId: newParentId);
    ref.invalidate(nodeProvider(node.id));
    return updated;
  }

  /// Moves several at once, which is what a drag onto a folder does.
  ///
  /// A refusal on one is not allowed to abandon the rest, the same way a batch
  /// trash behaves: the listing refresh at the end shows exactly what actually
  /// moved, so nothing has to be guessed from a half finished error.
  Future<int> moveMany(Iterable<NodeModel> nodes, String newParentId) async {
    final sources = <String>{};
    var moved = 0;

    for (final node in nodes) {
      if (node.id == newParentId || node.parentId == newParentId) continue;
      try {
        await _db.move(node.id, newParentId);
        sources.add(node.parentId);
        ref.invalidate(nodeProvider(node.id));
        moved++;
      } on ApiException {
        continue;
      }
    }

    for (final parentId in sources) {
      _invalidate(parentId: parentId);
    }
    _invalidate(parentId: newParentId);
    return moved;
  }

  Future<NodeModel> recolor(NodeModel node, String color) async {
    final updated = await _db.recolor(node.id, color);
    _invalidate(parentId: node.parentId);
    ref.invalidate(nodeProvider(node.id));
    return updated;
  }

  /// A star is this person's own bookmark, invisible to everyone else, so it
  /// only ever refreshes the starred view and the row itself.
  Future<void> setStarred(NodeModel node, bool starred) async {
    if (starred) {
      await _db.star(node.id);
    } else {
      await _db.unstar(node.id);
    }
    _invalidate(parentId: node.parentId, filter: NodeFilter.starred);
    ref.invalidate(nodeProvider(node.id));
  }

  Future<void> trash(NodeModel node) async {
    await _db.trash(node.id);
    _invalidate(parentId: node.parentId, filter: NodeFilter.shared);
    ref.invalidate(trashProvider);
  }

  Future<void> trashMany(Iterable<NodeModel> nodes) async {
    for (final node in nodes) {
      try {
        await _db.trash(node.id);
      } on ApiException {
        // one refusal in a batch should not abandon the rest; the list
        // refresh below shows exactly what actually moved
        continue;
      }
    }
    _invalidate(parentId: nodes.isEmpty ? '' : nodes.first.parentId);
    ref.invalidate(trashProvider);
  }

  Future<void> restore(NodeModel node) async {
    await _db.restore(node.id);
    ref.invalidate(trashProvider);
    _invalidate(parentId: node.parentId);
  }

  Future<void> deleteForever(NodeModel node) async {
    await _db.deleteForever(node.id);
    ref.invalidate(trashProvider);
    _invalidate(parentId: node.parentId);
  }

  Future<void> emptyTrash(Iterable<NodeModel> nodes) async {
    for (final node in nodes) {
      try {
        await _db.deleteForever(node.id);
      } on ApiException {
        continue;
      }
    }
    ref.invalidate(trashProvider);
  }

  Future<NodeModel> restoreVersion(String nodeId, String versionId) async {
    final updated = await _db.restoreVersion(nodeId, versionId);
    ref.invalidate(versionsProvider(nodeId));
    ref.invalidate(nodeProvider(nodeId));
    _invalidate(parentId: updated.parentId);
    return updated;
  }

  /// Called by the live event listener when the server says something changed,
  /// so an open folder updates without a refresh.
  void applyRemoteChange({String? parentId, String? nodeId}) {
    ref.invalidate(folderProvider(FolderQuery(parentId: parentId ?? '')));
    if (nodeId != null) ref.invalidate(nodeProvider(nodeId));
    if (parentId != null && parentId.isNotEmpty) {
      ref.invalidate(folderPreviewProvider(parentId));
    }
  }

  /// A full reconciliation after a reconnect, since events may have been
  /// missed while the socket was down.
  void reconcile() {
    ref.invalidate(folderProvider);
    ref.invalidate(nodeProvider);
    ref.invalidate(trashProvider);
    ref.invalidate(folderPreviewProvider);
  }
}

final filesControllerProvider =
    NotifierProvider<FilesController, void>(FilesController.new);
