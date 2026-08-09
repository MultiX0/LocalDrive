import '../../../imports.dart';
import '../../files/controller/files_controller.dart';
import '../../files/models/node_model.dart';
import '../../files/providers/files_providers.dart';
import '../../files/widgets/shared/node_tile.dart';

/// The trashed items themselves, with restore and permanent delete per row.
/// The chrome around this is what differs between a phone and a desktop.
class TrashList extends ConsumerWidget {
  const TrashList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final trash = ref.watch(trashProvider);

    return LdRefresh(
      onRefresh: () async {
        ref.invalidate(trashProvider);
        await ref.read(trashProvider.future);
      },
      child: LdAsync<List<NodeModel>>(
        value: trash,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(trashProvider),
        loading: const LdListSkeleton(),
        isEmpty: (nodes) => nodes.isEmpty,
        empty: () => LdEmptyState(
          title: l10n.emptyTrashTitle,
          message: l10n.emptyTrashBody,
          glyph: LdGlyph.trash,
        ),
        data: (nodes) => ListView.builder(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding - 8,
            8,
            context.pagePadding - 8,
            120,
          ),
          itemCount: nodes.length,
          itemBuilder: (context, index) {
            final node = nodes[index];
            return NodeRow(
              node: node,
              onOpen: () {},
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LdTappable(
                    onTap: () async {
                      await ref
                          .read(filesControllerProvider.notifier)
                          .restore(node);
                      if (context.mounted) {
                        LdToast.success(context, l10n.restore);
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: LdIcon(LdGlyph.restore, size: 18),
                    ),
                  ),
                  LdTappable(
                    onTap: () async {
                      final confirmed = await LdBottomSheet.confirm(
                        context,
                        title: l10n.confirmDeleteTitle,
                        message: l10n.confirmDeleteBody(node.name),
                        confirmLabel: l10n.permanentlyDelete,
                        cancelLabel: l10n.actionCancel,
                        destructive: true,
                      );
                      if (!confirmed) return;
                      await ref
                          .read(filesControllerProvider.notifier)
                          .deleteForever(node);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: LdIcon(
                        LdGlyph.trash,
                        size: 18,
                        color: LdColors.accentWarning,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
