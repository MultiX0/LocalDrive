import '../../../../imports.dart';
import '../../../files/providers/files_providers.dart';
import '../../../files/widgets/shared/files_browser.dart';
import '../../../files/widgets/shared/files_toolbar.dart';

/// Shared with me, on desktop. The title, the view controls, and the sort all
/// sit on the one top bar rather than stacked above the grid.
class SharedPageDesktop extends ConsumerWidget {
  const SharedPageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final viewMode = ref.watch(viewModeProvider);

    return LdDesktopScaffold(
      title: l10n.sharedWithMe,
      subtitle: l10n.sharePeopleHint,
      actions: <Widget>[
        Builder(
          builder: (context) => LdUtilityButton(
            glyph: LdGlyph.sort,
            tooltip: l10n.sortBy,
            onPressed: () =>
                showSortMenu(context, ref, anchor: anchorOf(context)),
          ),
        ),
        LdUtilityButton(
          glyph: viewMode == ViewMode.grid ? LdGlyph.list : LdGlyph.grid,
          tooltip: viewMode == ViewMode.grid ? l10n.viewList : l10n.viewGrid,
          onPressed: () => ref.read(viewModeProvider.notifier).toggle(),
        ),
      ],
      body: FilesBrowser(
        query: const FolderQuery(filter: NodeFilter.shared),
        emptyGlyph: LdGlyph.shared,
        emptyTitle: l10n.emptySharedTitle,
        emptyBody: l10n.emptySharedBody,
      ),
    );
  }
}
