import '../../../imports.dart';
import '../providers/gallery_providers.dart';

/// How the gallery is ordered and grouped, in one sheet.
///
/// The two belong together: changing the order to file size makes date
/// headings meaningless, and a sheet that let you pick both independently
/// would let you pick a combination that cannot be drawn. Here the grouping
/// options simply go quiet when the chosen order is not a timeline.
Future<void> showGallerySortSheet(BuildContext context, WidgetRef ref) {
  final l10n = L10n.of(context);
  return LdBottomSheet.show<void>(
    context,
    title: l10n.gallerySortTitle,
    builder: (sheetContext) => const _SortBody(),
  );
}

class _SortBody extends ConsumerWidget {
  const _SortBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final sort = ref.watch(gallerySortProvider);
    final grouping = ref.watch(galleryGroupingProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final option in GallerySort.values)
          _SortRow(
            label: _sortLabel(l10n, option),
            selected: sort.by == option,
            descending: sort.descending,
            onTap: () => ref.read(gallerySortProvider.notifier).set(option),
          ),
        const SizedBox(height: 20),
        Text(
          l10n.galleryGroupTitle,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: LdColors.foregroundMuted,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 8),
        // grouping only means anything for a timeline, so it says so rather
        // than offering a choice that would do nothing
        if (!sort.by.groupable)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              l10n.galleryGroupUnavailable,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: LdColors.foregroundSecondary,
                  ),
            ),
          )
        else
          for (final option in GalleryGrouping.values)
            LdRadioRow(
              label: _groupLabel(l10n, option),
              selected: grouping == option,
              onTap: () =>
                  ref.read(galleryGroupingProvider.notifier).set(option),
            ),
      ],
    );
  }

  static String _sortLabel(L10n l10n, GallerySort sort) => switch (sort) {
        GallerySort.taken => l10n.gallerySortTaken,
        GallerySort.added => l10n.gallerySortAdded,
        GallerySort.modified => l10n.gallerySortModified,
        GallerySort.name => l10n.gallerySortName,
        GallerySort.size => l10n.gallerySortSize,
      };

  static String _groupLabel(L10n l10n, GalleryGrouping grouping) =>
      switch (grouping) {
        GalleryGrouping.day => l10n.galleryGroupDay,
        GalleryGrouping.month => l10n.galleryGroupMonth,
        GalleryGrouping.year => l10n.galleryGroupYear,
        GalleryGrouping.none => l10n.galleryGroupNone,
      };
}

/// One order, with its direction shown on the chosen one.
///
/// Tapping the selected row flips the direction rather than doing nothing,
/// which is what everyone tries and what every file manager does.
class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.selected,
    required this.descending,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool descending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LdTappable(
      onTap: onTap,
      borderRadius: LdRadii.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: selected
                          ? LdColors.foregroundPrimary
                          : LdColors.foregroundSecondary,
                    ),
              ),
            ),
            if (selected)
              LdIcon(
                descending ? LdGlyph.arrowDown : LdGlyph.arrowUp,
                size: 18,
                color: LdColors.accentPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
