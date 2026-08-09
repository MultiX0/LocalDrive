import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/enums/file_category.dart';
import '../../../core/services/api_exception.dart';
import '../../../core/services/core_providers.dart';
import '../db/node_cache.dart';
import '../db/files_db.dart';
import '../models/node_model.dart';

final filesDbProvider = Provider<FilesDb>((ref) {
  return FilesDb(ref.watch(apiClientProvider));
});

/// The metadata cache, which makes a folder render instantly on
/// reopen and keeps the tree browsable with no connection at all.
final nodeCacheProvider = Provider<NodeCache>((ref) {
  return NodeCache(ref.watch(localDbProvider));
});

/// Which folder or filtered view a listing is for. Small and comparable, so
/// two identical requests share one provider instance.
class FolderQuery {
  const FolderQuery({
    this.parentId = '',
    this.filter = NodeFilter.none,
    this.query = '',
  });

  final String parentId;
  final String filter;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is FolderQuery &&
      other.parentId == parentId &&
      other.filter == filter &&
      other.query == query;

  @override
  int get hashCode => Object.hash(parentId, filter, query);
}

/// The sort choice, remembered per device rather than per folder.
class SortController extends Notifier<({SortBy by, bool descending})> {
  @override
  ({SortBy by, bool descending}) build() {
    _restore();
    return (by: SortBy.name, descending: false);
  }

  Future<void> _restore() async {
    final store = ref.read(secureStoreProvider);
    final saved = await store.readString(StorageKeys.sortBy);
    final descending = await store.readBool(StorageKeys.sortDescending);
    state = (by: SortBy.fromWire(saved), descending: descending);
  }

  Future<void> set(SortBy by, {bool? descending}) async {
    final next = descending ?? (state.by == by ? !state.descending : false);
    state = (by: by, descending: next);
    final store = ref.read(secureStoreProvider);
    await store.writeString(StorageKeys.sortBy, by.wire);
    await store.writeBool(StorageKeys.sortDescending, next);
  }
}

final sortProvider =
    NotifierProvider<SortController, ({SortBy by, bool descending})>(
  SortController.new,
);

/// Grid or list, remembered per device.
class ViewModeController extends Notifier<ViewMode> {
  @override
  ViewMode build() {
    _restore();
    return ViewMode.grid;
  }

  Future<void> _restore() async {
    final saved =
        await ref.read(secureStoreProvider).readString(StorageKeys.viewMode);
    if (saved == ViewMode.list.name) state = ViewMode.list;
  }

  Future<void> toggle() async {
    state = state.toggled;
    await ref
        .read(secureStoreProvider)
        .writeString(StorageKeys.viewMode, state.name);
  }
}

final viewModeProvider =
    NotifierProvider<ViewModeController, ViewMode>(ViewModeController.new);

/// One folder listing. autoDispose so a folder's state does not outlive the
/// screen that showed it.
final folderProvider =
    FutureProvider.autoDispose.family<List<NodeModel>, FolderQuery>(
  (ref, query) async {
    // a listing re-sorts when the sort choice changes, without a new provider
    final sort = ref.watch(sortProvider);
    ref.keepAlive();

    final cache = ref.watch(nodeCacheProvider);
    try {
      final nodes = await ref.watch(filesDbProvider).list(
            parentId: query.parentId,
            filter: query.filter,
            query: query.query,
            sortBy: sort.by,
            descending: sort.descending,
          );

      // only a plain folder listing is cached. A filter or a search is a
      // question, not a place, and answering it from stale rows would be
      // worse than saying the question needs a connection
      if (query.filter == NodeFilter.none && query.query.isEmpty) {
        unawaited(cache.write(query.parentId, nodes));
      }
      return nodes;
    } on ApiException catch (error) {
      // with no connection, the tree still renders from what this device
      // already saw. Anything not available offline says so on its own screen
      if (!error.kind.isConnectivity ||
          query.filter != NodeFilter.none ||
          query.query.isNotEmpty) {
        rethrow;
      }
      final cached = await cache.read(query.parentId);
      if (cached.isEmpty) rethrow;
      return cached;
    }
  },
);

/// One node's detail, for a preview screen or a share sheet.
final nodeProvider = FutureProvider.autoDispose.family<NodeModel, String>(
  (ref, id) => ref.watch(filesDbProvider).node(id),
);

/// A bounded prefix of one file as text, for the inline text and code reader.
/// autoDispose so leaving the screen drops the content rather than holding
/// half a megabyte of log file for the rest of the session.
final nodeTextProvider =
    FutureProvider.autoDispose.family<({String text, bool truncated}), String>(
  (ref, id) => ref.watch(filesDbProvider).textContent(id),
);

/// One file's whole bytes, for the formats that can only be parsed complete.
/// autoDispose so leaving the screen drops a spreadsheet rather than holding
/// it for the rest of the session.
final nodeBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, id) => ref.watch(filesDbProvider).fileBytes(id),
);

/// The breadcrumb for a folder.
final nodePathProvider =
    FutureProvider.autoDispose.family<List<NodeModel>, String>(
  (ref, id) async {
    if (id.isEmpty || id == Api.rootParent) return const <NodeModel>[];
    return ref.watch(filesDbProvider).path(id);
  },
);

/// The four thumbnails peeking out of a folder's icon.
final folderPreviewProvider =
    FutureProvider.autoDispose.family<List<NodePreviewModel>, String>(
  (ref, id) => ref.watch(filesDbProvider).folderPreview(id),
);

final versionsProvider =
    FutureProvider.autoDispose.family<List<NodeVersionModel>, String>(
  (ref, id) => ref.watch(filesDbProvider).versions(id),
);

/// The trash, with the retention policy the screen shows alongside it.
final trashProvider = FutureProvider.autoDispose<List<NodeModel>>((ref) {
  return ref.watch(filesDbProvider).trashList();
});

/// Which items a multi select action bar is holding.
class SelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String id) {
    final next = <String>{...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void selectAll(Iterable<String> ids) => state = <String>{...ids};

  void clear() {
    state = const <String>{};
    _anchor = '';
  }

  bool contains(String id) => state.contains(id);

  /// Exactly one thing selected, which is what a plain click on a desktop
  /// does: it replaces the selection rather than adding to it.
  void only(String id) {
    state = <String>{id};
    _anchor = id;
  }

  /// The item a shift click measures from.
  ///
  /// A range runs from the last item touched without shift, so clicking one
  /// file and shift clicking another five below selects the six between them,
  /// and shift clicking again from the same start grows or shrinks that run
  /// instead of starting a new one.
  String _anchor = '';
  String get anchor => _anchor;

  void toggleAt(String id) {
    toggle(id);
    _anchor = id;
  }

  /// Selects everything between the anchor and [id] in the order shown.
  ///
  /// With nothing anchored yet this behaves like a plain click, because a
  /// range needs two ends and inventing the first one would select a run
  /// nobody asked for.
  void selectRange(String id, List<String> ordered) {
    final from = ordered.indexOf(_anchor);
    final to = ordered.indexOf(id);
    if (from < 0 || to < 0) {
      only(id);
      return;
    }
    final lower = from <= to ? from : to;
    final upper = from <= to ? to : from;
    state = <String>{...ordered.sublist(lower, upper + 1)};
  }

  /// Replaces the selection with whatever a marquee drag covered.
  ///
  /// [additive] keeps what was already selected, which is what holding ctrl
  /// while dragging a box means everywhere else.
  void setMarquee(Set<String> ids, {required bool additive, Set<String>? base}) {
    state = additive ? <String>{...?base, ...ids} : ids;
  }
}

final selectionProvider =
    NotifierProvider<SelectionController, Set<String>>(SelectionController.new);

/// Whether the multi select action bar is showing at all.
final isSelectingProvider = Provider<bool>((ref) {
  return ref.watch(selectionProvider).isNotEmpty;
});
