import '../../../../imports.dart';
import '../../../share/widgets/share_sheet.dart';
import '../../controller/files_controller.dart';
import '../../models/node_model.dart';
import '../../providers/files_providers.dart';
import '../shared/rename_sheet.dart';

/// The right hand pane on desktop.
///
/// A phone has no room for this, so it opens a full preview screen instead.
/// With a wide window the useful thing is to keep the listing visible and put
/// what you selected beside it: a large preview, its facts, and the actions
/// that apply to it.
class NodeDetailsPane extends ConsumerWidget {
  const NodeDetailsPane({super.key, required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final db = ref.watch(filesDbProvider);

    return LdDetailPane(
      title: node.name,
      onClose: () => ref.read(selectionProvider.notifier).clear(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.35,
            child: LdFileTile(
              category: node.category,
              hasThumbnail: node.hasThumbnail,
              thumbnail: node.hasThumbnail
                  ? LdRemoteImage.provider(
                      url: db.thumbnailUrl(node.id),
                      headers: db.authHeaders,
                    )
                  : null,
              folderColor: node.color,
              size: 180,
              alwaysPeek: true,
            ),
          ),
          const SizedBox(height: 20),

          if (node.owner != null) ...<Widget>[
            Row(
              children: <Widget>[
                LdAvatar(
                  name: node.owner!.name,
                  seed: node.owner!.avatarSeed,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    node.owner!.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          _Fact(label: l10n.sortSize, value: node.isFolder
              ? l10n.itemCount(0)
              : LdFormat.bytes(context, node.sizeBytes)),
          _Fact(
            label: l10n.sortUpdated,
            value: LdFormat.relative(context, node.updatedAt),
          ),
          if (!node.isFolder && node.versionCount > 1)
            _Fact(
              label: l10n.versionHistory,
              value: '${node.versionCount}',
            ),
          if (node.hasActiveShare)
            _Fact(label: l10n.shareLinkTab, value: l10n.shareCreateLink),

          const SizedBox(height: 20),
          const Divider(height: 1, color: LdColors.strokeOutline),
          const SizedBox(height: 12),

          if (!node.isFolder)
            LdSettingRow(
              label: l10n.actionOpen,
              glyph: LdGlyph.eye,
              onTap: () => context.push(Routes.previewOf(node.id)),
            ),
          LdSettingRow(
            label: node.starred ? l10n.starred : l10n.starred,
            glyph: node.starred ? LdGlyph.starFilled : LdGlyph.star,
            onTap: () => ref
                .read(filesControllerProvider.notifier)
                .setStarred(node, !node.starred),
          ),
          if (node.role.canRename)
            LdSettingRow(
              label: l10n.actionRename,
              glyph: LdGlyph.edit,
              onTap: () => showRenameSheet(context, ref, node),
            ),
          if (node.role.canShare)
            LdSettingRow(
              label: l10n.actionShare,
              glyph: LdGlyph.shared,
              onTap: () => showShareSheet(context, ref, node),
            ),
          if (node.role.canTrash)
            LdSettingRow(
              label: l10n.trash,
              glyph: LdGlyph.trash,
              destructive: true,
              onTap: () async {
                final confirmed = await LdBottomSheet.confirm(
                  context,
                  title: l10n.confirmTrashTitle,
                  message: l10n.confirmTrashBody(node.name),
                  confirmLabel: l10n.actionDelete,
                  cancelLabel: l10n.actionCancel,
                  destructive: true,
                );
                if (!confirmed) return;
                await ref.read(filesControllerProvider.notifier).trash(node);
                ref.read(selectionProvider.notifier).clear();
              },
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: LdColors.foregroundPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
