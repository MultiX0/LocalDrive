import '../../../imports.dart';
import '../models/node_model.dart';
import '../providers/files_providers.dart';
import '../widgets/desktop/drop_zone.dart';
import '../widgets/shared/files_browser.dart';
import '../widgets/shared/files_toolbar.dart';
import 'desktop/files_page_desktop.dart';
import 'mobile/files_page_mobile.dart';
import 'tablet/files_page_tablet.dart';

/// Which view of the tree this page is showing.
enum FilesFilter {
  browse(NodeFilter.none),
  starred(NodeFilter.starred),
  recent(NodeFilter.recent);

  const FilesFilter(this.wire);
  final String wire;
}

/// No business logic here, only the breakpoint choice, per the structure guide.
class FilesPage extends StatelessWidget {
  const FilesPage({super.key, this.folderId, this.filter = FilesFilter.browse});

  final String? folderId;
  final FilesFilter filter;

  @override
  Widget build(BuildContext context) {
    return LdResponsive(
      mobile: (_) => FilesPageMobile(folderId: folderId, filter: filter),
      tablet: (_) => FilesPageTablet(folderId: folderId, filter: filter),
      desktop: (_) => FilesPageDesktop(folderId: folderId, filter: filter),
    );
  }
}

/// The parts every breakpoint shares, so the three page files differ in layout
/// rather than repeating the listing and its toolbar.
class FilesPageBody extends ConsumerWidget {
  const FilesPageBody({
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
    final query = FolderQuery(parentId: folderId ?? '', filter: filter.wire);
    final selecting = ref.watch(isSelectingProvider);

    final body = Column(
      children: <Widget>[
        if (selecting)
          _SelectionBar(query: query)
        else
          FilesToolbar(
            folderId: folderId,
            filter: filter,
            showBreadcrumb: showBreadcrumb,
          ),
        Expanded(
          child: FilesBrowser(
            query: query,
            emptyGlyph: switch (filter) {
              FilesFilter.starred => LdGlyph.star,
              FilesFilter.recent => LdGlyph.clock,
              FilesFilter.browse => LdGlyph.folder,
            },
            emptyTitle: switch (filter) {
              FilesFilter.starred => l10n.emptyStarredTitle,
              FilesFilter.recent => l10n.emptyRecentTitle,
              FilesFilter.browse => l10n.emptyFolderTitle,
            },
            emptyBody: switch (filter) {
              FilesFilter.starred => l10n.emptyStarredBody,
              FilesFilter.recent => l10n.emptyRecentBody,
              FilesFilter.browse => l10n.emptyFolderBody,
            },
          ),
        ),
      ],
    );

    // Dropping files from the desktop has to keep working when the window is
    // not maximised.
    //
    // Layout follows width, so a window under 1024 wide gets this body instead
    // of the desktop page, and the drop target used to live only on the
    // desktop page. Half covering a monitor therefore turned off dragging
    // files in, on the same machine, with the same mouse. Behaviour follows
    // the machine, not the window size.
    if (!desktopBehaviour(context)) return body;
    return FilesDropZone(folderId: folderId ?? '', child: body);
  }
}

/// Watches only the current listing, so the action bar rebuilding never drags
/// the whole page with it.
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.query});

  final FolderQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(
      folderProvider(query).select(
        (value) => value.maybeWhen(
          data: (list) => list,
          orElse: () => const <NodeModel>[],
        ),
      ),
    );
    return SelectionActionBar(nodes: nodes);
  }
}
