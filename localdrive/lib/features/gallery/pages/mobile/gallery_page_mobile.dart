import '../../../../imports.dart';
import '../../../files/models/node_model.dart';
import '../../../files/widgets/shared/node_actions.dart';
import '../../../share/widgets/share_sheet.dart';
import '../../providers/gallery_providers.dart';
import '../../widgets/gallery_grid.dart';
import '../../widgets/gallery_sort_sheet.dart';

/// The gallery on a phone.
///
/// A photo grid on a phone wants the whole width and nothing else on screen,
/// so the chrome is one slim row rather than the stacked header the file
/// browser uses. Pinch changes how many photos fit across, which is the
/// gesture every phone gallery has trained people to expect.
class GalleryPageMobile extends HookConsumerWidget {
  const GalleryPageMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final gallery = ref.watch(galleryProvider);
    final sort = ref.watch(gallerySortProvider);
    final grouping = ref.watch(galleryGroupingProvider);
    final summary = ref.watch(gallerySummaryProvider);

    final columns = useState(3);
    final selection = useState(<String>{});
    final pinchStart = useRef(3);

    void toggle(NodeModel node) {
      final next = <String>{...selection.value};
      if (!next.remove(node.id)) next.add(node.id);
      selection.value = next;
    }

    return LdScaffold(
      title: selection.value.isEmpty
          ? l10n.gallery
          : l10n.gallerySelected(selection.value.length),
      subtitle: selection.value.isEmpty
          ? l10n.gallerySummary(summary.photos, summary.videos)
          : null,
      showBack: selection.value.isNotEmpty,
      onBack: () => selection.value = <String>{},
      actions: <Widget>[
        if (selection.value.isEmpty)
          LdUtilityButton(
            glyph: LdGlyph.sort,
            tooltip: l10n.gallerySortTitle,
            onPressed: () => showGallerySortSheet(context, ref),
          )
        else ...<Widget>[
          LdUtilityButton(
            glyph: LdGlyph.download,
            tooltip: l10n.download,
            onPressed: () async {
              final nodes = _selected(gallery, selection.value);
              await downloadNodes(context, ref, nodes);
              selection.value = <String>{};
            },
          ),
          LdUtilityButton(
            glyph: LdGlyph.shared,
            tooltip: l10n.actionShare,
            onPressed: () async {
              final nodes = _selected(gallery, selection.value);
              if (nodes.length != 1) {
                // sharing grants access per item, so a multi select share is
                // several separate decisions rather than one. Rather than
                // pretend otherwise, this asks for one at a time
                LdToast.show(context, message: l10n.shareOneAtATime);
                return;
              }
              await showShareSheet(context, ref, nodes.first);
            },
          ),
        ],
      ],
      body: LdRefresh(
        onRefresh: () async => ref.invalidate(galleryProvider),
        child: LdAsync<List<NodeModel>>(
          value: gallery,
          errorCopy: LdFormat.errorCopy(context),
          onRetry: () => ref.invalidate(galleryProvider),
          loading: LdGridSkeleton(columns: columns.value, tiles: 18),
          isEmpty: (nodes) => nodes.isEmpty,
          empty: () => LdEmptyState(
            title: l10n.galleryEmptyTitle,
            message: l10n.galleryEmptyBody,
            glyph: LdGlyph.image,
            tint: LdColors.fileMedia,
          ),
          data: (nodes) {
            final sections = groupGallery(
              nodes,
              sort: sort.by,
              grouping: grouping,
              label: (moment, group) => LdFormat.galleryHeading(
                context,
                moment,
                day: group == GalleryGrouping.day,
                month: group == GalleryGrouping.month,
              ),
            );

            return GestureDetector(
              // pinch to change how many fit across, the gesture every phone
              // gallery has trained people to expect
              onScaleStart: (_) => pinchStart.value = columns.value,
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                final next = (pinchStart.value / details.scale).round();
                columns.value = next.clamp(2, 6);
              },
              child: GalleryGrid(
                sections: sections,
                columns: columns.value,
                selection: selection.value,
                onOpen: (node) => context.push(Routes.photo(node.id)),
                onToggleSelect: toggle,
              ),
            );
          },
        ),
      ),
    );
  }

  static List<NodeModel> _selected(
    AsyncValue<List<NodeModel>> gallery,
    Set<String> ids,
  ) =>
      gallery.maybeWhen(
        data: (nodes) =>
            nodes.where((node) => ids.contains(node.id)).toList(),
        orElse: () => const <NodeModel>[],
      );
}
