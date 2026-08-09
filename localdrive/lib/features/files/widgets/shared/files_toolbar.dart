import '../../../../imports.dart';
import '../../models/node_model.dart';
import '../../pages/files_page.dart';
import '../../providers/files_providers.dart';
import 'rename_sheet.dart';

/// The breadcrumb plus the sort, view, and create controls. It watches only
/// what it renders, so a change to the listing never rebuilds it.
class FilesToolbar extends ConsumerWidget {
  const FilesToolbar({
    super.key,
    required this.folderId,
    required this.filter,
    this.showBreadcrumb = true,
  });

  final String? folderId;
  final FilesFilter filter;
  final bool showBreadcrumb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final viewMode = ref.watch(viewModeProvider);
    // a phone, where the row has to share its width with the folder name
    final compact = LdDeviceScope.of(context).isMobile;

    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 8),
      child: Row(
        children: <Widget>[
          // Starred and Recent are not tab destinations, so on a phone they
          // hide the tab bar and need their own way out. My Files is the tab
          // itself and has nowhere to go back to.
          if (compact && filter != FilesFilter.browse) ...<Widget>[
            LdTappable(
              onTap: () => context.go(Routes.files),
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: LdIcon(LdGlyph.chevronLeft, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: showBreadcrumb && filter == FilesFilter.browse
                ? DesktopBreadcrumb(folderId: folderId)
                : Text(
                    switch (filter) {
                      FilesFilter.starred => l10n.starred,
                      FilesFilter.recent => l10n.recent,
                      FilesFilter.browse => l10n.myFiles,
                    },
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
          ),
          // the title is Expanded, so without this it ends exactly where the
          // first button begins and a long folder name reads as if it is
          // touching the search icon
          const SizedBox(width: 16),
          // On a phone this row has to share about 375 points with the folder
          // name. Four controls at the minimum tap size plus their gaps come
          // to 216 of it, which leaves the name a stub and reads as a row of
          // crammed icons. So the phone keeps the one control people reach for
          // constantly and folds the rest into a menu, the way every file app
          // on a phone does it. A wide window has room for all of them.
          if (compact) ...<Widget>[
            LdUtilityButton(
              glyph: LdGlyph.search,
              tooltip: l10n.navSearch,
              onPressed: () => context.go(Routes.search),
            ),
            const SizedBox(width: 4),
            LdUtilityButton(
              glyph: LdGlyph.more,
              tooltip: l10n.moreActions,
              onPressed: () => _showOverflow(context, ref, viewMode),
            ),
          ] else ...<Widget>[
            if (!desktopBehaviour(context)) ...<Widget>[
              LdUtilityButton(
                glyph: LdGlyph.search,
                tooltip: l10n.navSearch,
                onPressed: () => context.go(Routes.search),
              ),
              const SizedBox(width: 8),
            ],
            LdUtilityButton(
              glyph: LdGlyph.sort,
              tooltip: l10n.sortBy,
              onPressed: () => _pickSort(context, ref),
            ),
            const SizedBox(width: 8),
            LdUtilityButton(
              glyph: viewMode == ViewMode.grid ? LdGlyph.list : LdGlyph.grid,
              tooltip: viewMode == ViewMode.grid ? l10n.viewList : l10n.viewGrid,
              onPressed: () => ref.read(viewModeProvider.notifier).toggle(),
            ),
            if (filter == FilesFilter.browse) ...<Widget>[
              const SizedBox(width: 8),
              LdUtilityButton(
                glyph: LdGlyph.plus,
                tooltip: l10n.newFolder,
                onPressed: () => showNewFolderSheet(
                  context,
                  ref,
                  parentId: folderId ?? '',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Everything the phone toolbar could not fit, in one sheet.
  ///
  /// A sheet rather than a popup menu: it is reachable with a thumb, its rows
  /// are full width so they are hard to miss, and it is the same control the
  /// rest of the app already opens for a list of actions.
  Future<void> _showOverflow(
    BuildContext context,
    WidgetRef ref,
    ViewMode viewMode,
  ) async {
    final l10n = L10n.of(context);
    final grid = viewMode == ViewMode.grid;

    final choice = await LdContextMenu.show(
      context,
      title: l10n.moreActions,
      actions: <LdMenuAction>[
        if (filter == FilesFilter.browse)
          LdMenuAction(
            id: 'folder',
            label: l10n.newFolder,
            glyph: LdGlyph.folder,
          ),
        LdMenuAction(id: 'sort', label: l10n.sortBy, glyph: LdGlyph.sort),
        LdMenuAction(
          id: 'view',
          label: grid ? l10n.viewList : l10n.viewGrid,
          glyph: grid ? LdGlyph.list : LdGlyph.grid,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'folder':
        await showNewFolderSheet(context, ref, parentId: folderId ?? '');
      case 'sort':
        await _pickSort(context, ref);
      case 'view':
        ref.read(viewModeProvider.notifier).toggle();
    }
  }

  Future<void> _pickSort(BuildContext context, WidgetRef ref) =>
      showSortMenu(context, ref);
}

/// The sort choice, shared by the mobile toolbar and the desktop top bar.
///
/// [anchor] is the sort button's own position. On a desktop the list opens
/// there as a small panel; on a phone there is nothing to anchor to and it
/// stays a sheet, which is what a thumb wants anyway.
Future<void> showSortMenu(
  BuildContext context,
  WidgetRef ref, {
  Offset? anchor,
}) async {
  final l10n = L10n.of(context);
  final current = ref.read(sortProvider);
  final choice = await LdContextMenu.show(
    context,
    title: l10n.sortBy,
    anchor: anchor,
    actions: <LdMenuAction>[
      LdMenuAction(
        id: SortBy.name.wire,
        label: l10n.sortName,
        glyph: current.by == SortBy.name
            ? (current.descending ? LdGlyph.arrowDown : LdGlyph.arrowUp)
            : LdGlyph.sort,
      ),
      LdMenuAction(
        id: SortBy.updated.wire,
        label: l10n.sortUpdated,
        glyph: current.by == SortBy.updated
            ? (current.descending ? LdGlyph.arrowDown : LdGlyph.arrowUp)
            : LdGlyph.clock,
      ),
      LdMenuAction(
        id: SortBy.size.wire,
        label: l10n.sortSize,
        glyph: current.by == SortBy.size
            ? (current.descending ? LdGlyph.arrowDown : LdGlyph.arrowUp)
            : LdGlyph.filter,
      ),
    ],
  );
  if (choice == null) return;
  await ref.read(sortProvider.notifier).set(SortBy.fromWire(choice));
}

/// The path from the top level down to the folder being shown. On desktop it
/// is the top bar's title; on mobile it sits in the toolbar underneath.
class DesktopBreadcrumb extends ConsumerWidget {
  const DesktopBreadcrumb({super.key, required this.folderId, this.filter});

  final String? folderId;
  final FilesFilter? filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final id = folderId ?? '';

    if (filter == FilesFilter.starred) {
      return Text(l10n.starred, style: Theme.of(context).textTheme.titleLarge);
    }
    if (filter == FilesFilter.recent) {
      return Text(l10n.recent, style: Theme.of(context).textTheme.titleLarge);
    }

    if (id.isEmpty) {
      return Text(l10n.myFiles, style: Theme.of(context).textTheme.titleLarge);
    }

    final path = ref.watch(nodePathProvider(id));
    return path.maybeWhen(
      loading: () => const LdSkeleton(width: 160, height: 18),
      data: (nodes) => _BreadcrumbRow(nodes: nodes, rootLabel: l10n.myFiles),
      orElse: () =>
          Text(l10n.myFiles, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _BreadcrumbRow extends StatelessWidget {
  const _BreadcrumbRow({required this.nodes, required this.rootLabel});

  final List<NodeModel> nodes;
  final String rootLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // a deep path keeps its ends and drops the middle, which is what a person
    // actually needs to see
    final visible = nodes.length > 3
        ? <NodeModel?>[nodes.first, null, nodes[nodes.length - 2], nodes.last]
        : <NodeModel?>[...nodes];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: <Widget>[
          LdTappable(
            onTap: () => context.go(Routes.files),
            borderRadius: LdRadii.chipRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                rootLabel,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          for (var i = 0; i < visible.length; i++) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: LdIcon(
                LdGlyph.chevronRight,
                size: 14,
                color: LdColors.foregroundMuted,
              ),
            ),
            if (visible[i] == null)
              Text('...', style: theme.textTheme.bodyMedium)
            else
              LdTappable(
                onTap: i == visible.length - 1
                    ? null
                    : () => context.go(Routes.folder(visible[i]!.id)),
                borderRadius: LdRadii.chipRadius,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    visible[i]!.name,
                    style: i == visible.length - 1
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
