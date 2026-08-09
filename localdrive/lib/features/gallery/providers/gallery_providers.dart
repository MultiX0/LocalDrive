import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/enums/file_category.dart';
import '../../../core/services/core_providers.dart';
import '../../files/models/node_model.dart';
import '../../files/providers/files_providers.dart';

/// How the gallery is ordered.
///
/// Deliberately not the same list the file browser offers. A photo grid is
/// ordered by when a picture was taken far more often than by anything else,
/// and "taken" is a field a file listing has no concept of.
enum GallerySort {
  taken('taken'),
  added('created'),
  modified('updated'),
  name('name'),
  size('size');

  const GallerySort(this.wire);

  final String wire;

  static GallerySort fromWire(String? raw) => GallerySort.values.firstWhere(
        (sort) => sort.wire == raw,
        orElse: () => GallerySort.taken,
      );

  /// Newest first is right for a timeline and wrong for a name. Nobody wants
  /// their photos alphabetised backwards by default.
  bool get defaultDescending => this != GallerySort.name;

  /// Only a time based order can be grouped into days and months. Grouping a
  /// list sorted by file size under date headings would be nonsense.
  bool get groupable =>
      this == GallerySort.taken ||
      this == GallerySort.added ||
      this == GallerySort.modified;
}

/// How finely a timeline is broken up.
enum GalleryGrouping { day, month, year, none }

/// The current ordering, remembered per device.
class GallerySortController
    extends Notifier<({GallerySort by, bool descending})> {
  @override
  ({GallerySort by, bool descending}) build() {
    _restore();
    return (by: GallerySort.taken, descending: true);
  }

  Future<void> _restore() async {
    final store = ref.read(secureStoreProvider);
    final saved = await store.readString(StorageKeys.gallerySort);
    if (saved == null || saved.isEmpty) return;
    final by = GallerySort.fromWire(saved);
    state = (
      by: by,
      descending: await store.readBool(StorageKeys.gallerySortDescending),
    );
  }

  Future<void> set(GallerySort by) async {
    // choosing a different field resets the direction to whatever is sensible
    // for that field, rather than carrying over a direction that made sense
    // for the last one
    final descending =
        state.by == by ? !state.descending : by.defaultDescending;
    state = (by: by, descending: descending);

    final store = ref.read(secureStoreProvider);
    await store.writeString(StorageKeys.gallerySort, by.wire);
    await store.writeBool(StorageKeys.gallerySortDescending, descending);
  }
}

final gallerySortProvider = NotifierProvider<GallerySortController,
    ({GallerySort by, bool descending})>(GallerySortController.new);

/// How the timeline is broken up, remembered per device.
class GalleryGroupingController extends Notifier<GalleryGrouping> {
  @override
  GalleryGrouping build() {
    _restore();
    // One continuous feed by default. Month headings cut the grid into short
    // rows with a gap and a title between them, which stops the eye on every
    // break and wastes the width on a phone. Someone looking for a particular
    // month can switch to it; someone browsing wants to keep scrolling.
    return GalleryGrouping.none;
  }

  Future<void> _restore() async {
    final saved = await ref
        .read(secureStoreProvider)
        .readString(StorageKeys.galleryGrouping);
    if (saved == null) return;
    for (final grouping in GalleryGrouping.values) {
      if (grouping.name == saved) state = grouping;
    }
  }

  Future<void> set(GalleryGrouping grouping) async {
    state = grouping;
    await ref
        .read(secureStoreProvider)
        .writeString(StorageKeys.galleryGrouping, grouping.name);
  }
}

final galleryGroupingProvider =
    NotifierProvider<GalleryGroupingController, GalleryGrouping>(
  GalleryGroupingController.new,
);

/// Every picture and clip this account can reach, in one flat stream. Not a
/// folder listing with a filter on it: folders organise files, this is a
/// separate view over the same content.
final galleryProvider = FutureProvider.autoDispose<List<NodeModel>>((ref) async {
  final sort = ref.watch(gallerySortProvider);
  ref.keepAlive();

  return ref.watch(filesDbProvider).list(
        filter: NodeFilter.gallery,
        sortBy: SortBy.fromWire(sort.by.wire),
        descending: sort.descending,
        limit: 500,
      );
});

/// One run of items under one heading.
class GallerySection {
  const GallerySection({required this.label, required this.items});

  /// empty when the grouping is off, in which case there is no heading
  final String label;
  final List<NodeModel> items;
}

/// Splits the stream into the runs the grid draws headings for.
///
/// The split happens on the field the list is actually sorted by. Grouping a
/// list ordered by capture time under headings taken from upload time would
/// produce headings that do not match the order underneath them, which reads
/// as a bug even though every individual item is in the right place.
List<GallerySection> groupGallery(
  List<NodeModel> nodes, {
  required GallerySort sort,
  required GalleryGrouping grouping,
  required String Function(DateTime moment, GalleryGrouping grouping) label,
}) {
  if (nodes.isEmpty) return const <GallerySection>[];
  if (grouping == GalleryGrouping.none || !sort.groupable) {
    return <GallerySection>[GallerySection(label: '', items: nodes)];
  }

  final sections = <GallerySection>[];
  var current = <NodeModel>[];
  String? currentLabel;

  for (final node in nodes) {
    final millis = switch (sort) {
      GallerySort.taken => node.capturedAt,
      GallerySort.added => node.createdAt,
      _ => node.updatedAt,
    };
    final heading = millis <= 0
        ? ''
        : label(
            DateTime.fromMillisecondsSinceEpoch(millis),
            grouping,
          );

    if (heading != currentLabel) {
      if (currentLabel != null) {
        sections.add(GallerySection(label: currentLabel, items: current));
      }
      currentLabel = heading;
      current = <NodeModel>[];
    }
    current.add(node);
  }

  if (currentLabel != null && current.isNotEmpty) {
    sections.add(GallerySection(label: currentLabel, items: current));
  }
  return sections;
}

/// What the gallery counts, for the header line.
final gallerySummaryProvider =
    Provider.autoDispose<({int photos, int videos})>((ref) {
  return ref.watch(galleryProvider).maybeWhen(
        data: (nodes) {
          var photos = 0;
          var videos = 0;
          for (final node in nodes) {
            if (node.category == FileCategory.video) {
              videos++;
            } else {
              photos++;
            }
          }
          return (photos: photos, videos: videos);
        },
        orElse: () => (photos: 0, videos: 0),
      );
});
