import '../../../../imports.dart';
import '../../../files/providers/files_providers.dart';
import '../../widgets/trash_list.dart';
import '../desktop/trash_page_desktop.dart';

/// The trash, on a phone: the retention policy as a banner rather than a
/// subtitle, because there is no room for one on the title row.
class TrashPageMobile extends ConsumerWidget {
  const TrashPageMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final trash = ref.watch(trashProvider);

    return Column(
      children: <Widget>[
        LdPageHeader(
          title: l10n.trash,
          onBack: () => context.go(Routes.settings),
          actions: <Widget>[
            trash.maybeWhen(
              data: (nodes) => nodes.isEmpty
                  ? const SizedBox.shrink()
                  : LdButton.destructive(
                      label: l10n.emptyTrashAction,
                      compact: true,
                      expand: false,
                      onPressed: () => emptyTrash(context, ref, nodes),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        LdBanner(
          message: l10n.trashRetentionNote(30),
          glyph: LdGlyph.clock,
          tint: LdColors.foregroundSecondary,
        ),
        const Expanded(child: TrashList()),
      ],
    );
  }
}
