import '../../../../imports.dart';
import '../../../files/models/node_model.dart';
import '../../../files/widgets/shared/node_actions.dart';
import '../../../share/widgets/share_sheet.dart';
import '../../providers/gallery_providers.dart';
import '../../widgets/gallery_grid.dart';
import '../../widgets/gallery_sort_sheet.dart';

/// The gallery on desktop.
///
/// Two things a phone cannot do, both of which change the design rather than
/// the spacing. The ordering and grouping live inline in the top bar instead
/// of behind a sheet, because there is room and because a photo grid is
/// re-sorted constantly. And a size slider replaces pinch, since a mouse has
/// no pinch and a hidden keyboard shortcut is not a control.
class GalleryPageDesktop extends HookConsumerWidget {
  const GalleryPageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final gallery = ref.watch(galleryProvider);
    final sort = ref.watch(gallerySortProvider);
    final grouping = ref.watch(galleryGroupingProvider);
    final summary = ref.watch(gallerySummaryProvider);

    final columns = useState(5);
    final selection = useState(<String>{});

    void toggle(NodeModel node) {
      final next = <String>{...selection.value};
      if (!next.remove(node.id)) next.add(node.id);
      selection.value = next;
    }

    final selected = gallery.maybeWhen(
      data: (nodes) =>
          nodes.where((node) => selection.value.contains(node.id)).toList(),
      orElse: () => const <NodeModel>[],
    );

    return LdDesktopScaffold(
      title: l10n.gallery,
      subtitle: selection.value.isEmpty
          ? l10n.gallerySummary(summary.photos, summary.videos)
          : l10n.gallerySelected(selection.value.length),
      actions: <Widget>[
        if (selection.value.isNotEmpty) ...<Widget>[
          LdButton.secondary(
            label: l10n.download,
            glyph: LdGlyph.download,
            compact: true,
            expand: false,
            onPressed: () async {
              await downloadNodes(context, ref, selected);
              selection.value = <String>{};
            },
          ),
          const SizedBox(width: 8),
          if (selected.length == 1)
            LdButton.secondary(
              label: l10n.actionShare,
              glyph: LdGlyph.shared,
              compact: true,
              expand: false,
              onPressed: () => showShareSheet(context, ref, selected.first),
            ),
          const SizedBox(width: 8),
          LdButton.text(
            label: l10n.actionDeselect,
            onPressed: () => selection.value = <String>{},
          ),
          const SizedBox(width: 16),
        ],
        // the size control, which on a pointer has to be a real control
        _SizeSlider(
          columns: columns.value,
          onChanged: (value) => columns.value = value,
        ),
        const SizedBox(width: 16),
        LdButton.secondary(
          label: _sortLabel(l10n, sort.by),
          glyph: sort.descending ? LdGlyph.arrowDown : LdGlyph.arrowUp,
          compact: true,
          expand: false,
          onPressed: () => showGallerySortSheet(context, ref),
        ),
      ],
      body: LdAsync<List<NodeModel>>(
        value: gallery,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(galleryProvider),
        loading: LdGridSkeleton(columns: columns.value, tiles: 24),
        isEmpty: (nodes) => nodes.isEmpty,
        empty: () => LdEmptyState(
          title: l10n.galleryEmptyTitle,
          message: l10n.galleryEmptyBody,
          glyph: LdGlyph.image,
          tint: LdColors.fileMedia,
        ),
        data: (nodes) => GalleryGrid(
          sections: groupGallery(
            nodes,
            sort: sort.by,
            grouping: grouping,
            label: (moment, group) => LdFormat.galleryHeading(
              context,
              moment,
              day: group == GalleryGrouping.day,
              month: group == GalleryGrouping.month,
            ),
          ),
          columns: columns.value,
          selection: selection.value,
          onOpen: (node) => context.push(Routes.photo(node.id)),
          onToggleSelect: toggle,
        ),
      ),
    );
  }

  static String _sortLabel(L10n l10n, GallerySort sort) => switch (sort) {
        GallerySort.taken => l10n.gallerySortTaken,
        GallerySort.added => l10n.gallerySortAdded,
        GallerySort.modified => l10n.gallerySortModified,
        GallerySort.name => l10n.gallerySortName,
        GallerySort.size => l10n.gallerySortSize,
      };
}

/// How many photos fit across, as a row of steps rather than a slider.
///
/// Five discrete sizes, because a continuous slider over an integer column
/// count snaps anyway and only looks like it offers more than it does.
class _SizeSlider extends StatelessWidget {
  const _SizeSlider({required this.columns, required this.onChanged});

  final int columns;
  final ValueChanged<int> onChanged;

  static const List<int> steps = <int>[3, 4, 5, 6, 8];

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).galleryColumns,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: LdColors.backgroundElevated,
          borderRadius: LdRadii.pillRadius,
          border: Border.all(color: LdColors.strokeOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final step in steps)
              LdTappable(
                onTap: () => onChanged(step),
                borderRadius: LdRadii.pillRadius,
                child: AnimatedContainer(
                  duration: LdMotion.tapFade,
                  width: 30,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: step == columns
                        ? LdColors.accentPrimary
                        : Colors.transparent,
                    borderRadius: LdRadii.pillRadius,
                  ),
                  child: CustomPaint(
                    size: const Size.square(13),
                    painter: _GridGlyph(
                      cells: step >= 6 ? 3 : 2,
                      color: step == columns
                          ? LdColors.foregroundPrimary
                          : LdColors.foregroundSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A grid of squares, more of them for a smaller tile size. Drawn rather than
/// pulled from the icon set, because this one has to vary.
class _GridGlyph extends CustomPainter {
  const _GridGlyph({required this.cells, required this.color});

  final int cells;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final gap = size.width * 0.16;
    final cell = (size.width - gap * (cells - 1)) / cells;

    for (var x = 0; x < cells; x++) {
      for (var y = 0; y < cells; y++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * (cell + gap), y * (cell + gap), cell, cell),
            Radius.circular(cell * 0.22),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridGlyph oldDelegate) =>
      oldDelegate.cells != cells || oldDelegate.color != color;
}
