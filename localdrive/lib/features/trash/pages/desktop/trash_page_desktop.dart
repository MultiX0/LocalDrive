import '../../../../imports.dart';
import '../../../files/controller/files_controller.dart';
import '../../../files/models/node_model.dart';
import '../../../files/providers/files_providers.dart';
import '../../widgets/trash_list.dart';

/// The trash, on desktop. Emptying it is a top bar action rather than a button
/// squeezed beside the title, and the retention policy is the subtitle.
class TrashPageDesktop extends ConsumerWidget {
  const TrashPageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final trash = ref.watch(trashProvider);

    return LdDesktopScaffold(
      title: l10n.trash,
      subtitle: l10n.trashRetentionNote(30),
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
      body: const TrashList(),
    );
  }
}

/// Shared by both breakpoints, so the confirmation reads the same either way.
Future<void> emptyTrash(
  BuildContext context,
  WidgetRef ref,
  List<NodeModel> nodes,
) async {
  final l10n = L10n.of(context);
  final confirmed = await LdBottomSheet.confirm(
    context,
    title: l10n.emptyTrashAction,
    message: l10n.confirmDeleteBody(l10n.trash),
    confirmLabel: l10n.permanentlyDelete,
    cancelLabel: l10n.actionCancel,
    destructive: true,
  );
  if (!confirmed) return;
  await ref.read(filesControllerProvider.notifier).emptyTrash(nodes);
}
