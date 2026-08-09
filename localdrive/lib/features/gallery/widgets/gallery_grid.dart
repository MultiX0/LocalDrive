import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../imports.dart';
import '../../files/models/node_model.dart';
import '../providers/gallery_providers.dart';
import 'gallery_tile.dart';

/// The masonry grid, with its date headings.
///
/// Masonry rather than a uniform square grid, because a square grid crops
/// every photo to fit and a panorama then looks like a close-up of its middle.
/// Each picture keeps its own shape, which is the point of looking at it.
///
/// One scroll view for the whole timeline, with the headings as slivers
/// between the sections, so scrolling from January to last week never stutters
/// at a section boundary the way a list of nested grids does.
class GalleryGrid extends ConsumerWidget {
  const GalleryGrid({
    super.key,
    required this.sections,
    required this.columns,
    required this.selection,
    required this.onOpen,
    required this.onToggleSelect,
  });

  final List<GallerySection> sections;
  final int columns;
  final Set<String> selection;
  final void Function(NodeModel node) onOpen;
  final void Function(NodeModel node) onToggleSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.pagePadding;

    return CustomScrollView(
      slivers: <Widget>[
        for (final section in sections) ...<Widget>[
          if (section.label.isNotEmpty)
            SliverPersistentHeader(
              // headings stick while their own section is on screen, so it is
              // always clear which month is being looked at
              pinned: true,
              delegate: _HeadingDelegate(
                label: section.label,
                count: section.items.length,
                padding: padding,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 8, padding, 20),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: columns,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childCount: section.items.length,
              itemBuilder: (context, index) {
                final node = section.items[index];
                return GalleryTile(
                  node: node,
                  selected: selection.contains(node.id),
                  selecting: selection.isNotEmpty,
                  onOpen: () => onOpen(node),
                  onToggleSelect: () => onToggleSelect(node),
                );
              },
            ),
          ),
        ],
        // room under the last row for the floating navigation to sit over
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _HeadingDelegate extends SliverPersistentHeaderDelegate {
  const _HeadingDelegate({
    required this.label,
    required this.count,
    required this.padding,
  });

  final String label;
  final int count;
  final double padding;

  static const double _height = 46;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _height,
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsetsDirectional.only(start: padding, end: padding),
      // opaque, because a pinned heading over a scrolling photo is unreadable
      color: LdColors.backgroundPrimary,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            LdFormat.count(context, count),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: LdColors.foregroundMuted,
                ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeadingDelegate oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.count != count ||
      oldDelegate.padding != padding;
}
