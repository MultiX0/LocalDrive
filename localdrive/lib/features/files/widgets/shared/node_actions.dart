import '../../../../imports.dart';
import '../../../share/widgets/share_sheet.dart';
import '../../../offline/controller/offline_controller.dart';
import '../../../upload/controller/transfer_controller.dart';
import '../../controller/files_controller.dart';
import '../../models/node_model.dart';
import '../../providers/files_providers.dart';
import 'rename_sheet.dart';

/// The per-node menu. Every entry is gated by the same capability matrix the
/// server enforces, so nothing offers an action that would be refused.
Future<void> showNodeActions(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
  Offset anchor, {
  /// true when this menu was opened from the preview or the photo viewer.
  /// Offering Open there pushes another copy of the screen already on
  /// screen, and doing it twice leaves a stack of identical pages to back
  /// out of one at a time.
  bool alreadyOpen = false,
}) async {
  final l10n = L10n.of(context);

  final actions = <LdMenuAction>[
    if (!alreadyOpen)
      LdMenuAction(
        id: 'open',
        label: l10n.actionOpen,
        glyph: node.isFolder ? LdGlyph.folder : LdGlyph.eye,
      ),
    LdMenuAction(
      id: 'star',
      label: node.starred ? l10n.starred : l10n.starred,
      glyph: node.starred ? LdGlyph.starFilled : LdGlyph.star,
    ),
    if (!node.isFolder)
      LdMenuAction(
        id: 'download',
        label: l10n.download,
        glyph: LdGlyph.download,
      ),
    // not offered in a browser tab, which has no filesystem to keep bytes in
    if (OfflineController.isSupported)
      LdMenuAction(
        id: 'offline',
        label: ref.read(isOfflineProvider(node.id))
            ? l10n.offlineRemoveDownload
            : l10n.offlineMakeAvailable,
        glyph: LdGlyph.offlineReady,
      ),
    LdMenuAction(
      id: 'rename',
      label: l10n.actionRename,
      glyph: LdGlyph.edit,
      enabled: node.role.canRename,
    ),
    if (node.isFolder)
      LdMenuAction(
        id: 'color',
        label: l10n.folderColor,
        glyph: LdGlyph.grid,
        enabled: node.role.canRecolor,
      ),
    LdMenuAction(
      id: 'move',
      label: l10n.actionMove,
      glyph: LdGlyph.move,
      enabled: node.role.canMove,
    ),
    LdMenuAction(
      id: 'share',
      label: l10n.actionShare,
      glyph: LdGlyph.shared,
      enabled: node.role.canShare,
    ),
    if (!node.isFolder && node.versionCount > 1)
      LdMenuAction(
        id: 'versions',
        label: l10n.versionHistory,
        glyph: LdGlyph.clock,
      ),
    LdMenuAction(
      id: 'trash',
      label: l10n.trash,
      glyph: LdGlyph.trash,
      destructive: true,
      enabled: node.role.canTrash,
    ),
  ];

  final choice = await LdContextMenu.show(
    context,
    title: node.name,
    subtitle: node.isFolder
        ? null
        : '${LdFormat.bytes(context, node.sizeBytes)} '
            '${LdFormat.relative(context, node.updatedAt)}',
    actions: actions,
    anchor: anchor == Offset.zero ? null : anchor,
  );
  if (choice == null || !context.mounted) return;

  final controller = ref.read(filesControllerProvider.notifier);

  switch (choice) {
    case 'open':
      if (node.isFolder) {
        context.go(Routes.folder(node.id));
      } else {
        context.push(Routes.previewOf(node.id));
      }

    case 'star':
      await controller.setStarred(node, !node.starred);

    case 'download':
      await downloadNodes(context, ref, <NodeModel>[node]);

    case 'offline':
      final offline = ref.read(offlineControllerProvider.notifier);
      if (await offline.isMarked(node.id)) {
        await offline.unmark(node);
        if (context.mounted) {
          LdToast.show(context, message: l10n.offlineRemoved(node.name));
        }
        break;
      }

      // warn before filling the device, rather than silently doing it. It is
      // a warning and not a refusal: telling someone what it will cost beats
      // declining to keep a file they asked for
      final usage = await offline.usage();
      final projected = usage.totalBytes + node.sizeBytes;
      if (usage.softCapBytes > 0 && projected > usage.softCapBytes) {
        if (!context.mounted) break;
        final proceed = await LdBottomSheet.confirm(
          context,
          title: l10n.offlineOverCapTitle,
          message: l10n.offlineOverCapBody(
            LdFormat.bytes(context, projected),
            LdFormat.bytes(context, usage.softCapBytes),
          ),
          confirmLabel: l10n.offlineMakeAvailable,
          cancelLabel: l10n.actionCancel,
        );
        if (!proceed) break;
      }

      await offline.mark(node);
      if (context.mounted) {
        LdToast.success(context, l10n.offlineQueued(node.name));
      }

    case 'rename':
      await showRenameSheet(context, ref, node);

    case 'color':
      await showColorSheet(context, ref, node);

    case 'move':
      if (context.mounted) {
        LdToast.show(context, message: l10n.moveTo);
      }

    case 'share':
      await showShareSheet(context, ref, node);

    case 'versions':
      if (context.mounted) {
        await showVersionsSheet(context, ref, node);
      }

    case 'trash':
      final confirmed = await LdBottomSheet.confirm(
        context,
        title: l10n.confirmTrashTitle,
        message: l10n.confirmTrashBody(node.name),
        confirmLabel: l10n.actionDelete,
        cancelLabel: l10n.actionCancel,
        destructive: true,
      );
      if (!confirmed) return;
      await controller.trash(node);
      if (context.mounted) LdToast.success(context, l10n.trash);
  }
}

/// The folder recolor sheet: a preset swatch row, applied immediately.
Future<void> showColorSheet(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
) async {
  final l10n = L10n.of(context);
  await LdBottomSheet.show<void>(
    context,
    title: l10n.folderColor,
    subtitle: node.name,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, sheetRef, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LdColorPicker(
          selected: node.color,
          onSelected: (color) async {
            Navigator.of(sheetContext).pop();
            await sheetRef
                .read(filesControllerProvider.notifier)
                .recolor(node, color);
          },
        ),
      ),
    ),
  );
}

/// Version history, with restore. Restoring keeps the outgoing bytes as a new
/// version, so the move is itself reversible.
Future<void> showVersionsSheet(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
) async {
  final l10n = L10n.of(context);
  await LdBottomSheet.show<void>(
    context,
    title: l10n.versionHistory,
    subtitle: node.name,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, sheetRef, _) {
        final versions = sheetRef.watch(versionsProvider(node.id));
        return LdAsync<List<NodeVersionModel>>(
          value: versions,
          compact: true,
          errorCopy: LdFormat.errorCopy(sheetContext),
          onRetry: () => sheetRef.invalidate(versionsProvider(node.id)),
          loading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: LdSpinner()),
          ),
          isEmpty: (list) => list.isEmpty,
          empty: () => LdEmptyState(
            title: l10n.versionCurrent,
            glyph: LdGlyph.clock,
            compact: true,
          ),
          data: (list) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final version in list)
                LdSettingRow(
                  label: LdFormat.relative(sheetContext, version.createdAt),
                  description: LdFormat.bytes(sheetContext, version.sizeBytes),
                  glyph: LdGlyph.clock,
                  trailing: LdButton.text(
                    label: l10n.restore,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await sheetRef
                          .read(filesControllerProvider.notifier)
                          .restoreVersion(node.id, version.id);
                      if (context.mounted) {
                        LdToast.success(context, l10n.versionRestored);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Flips one node's star. Small enough to be worth having in one place rather
/// than repeated wherever a star is tappable.
Future<void> toggleStar(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
) =>
    ref.read(filesControllerProvider.notifier).setStarred(node, !node.starred);

/// Queues one or more files for download and says so.
///
/// It goes through the transfer queue rather than fetching inline, so leaving
/// the screen, locking the phone, or losing the connection halfway does not
/// lose the download. Folders are skipped: there is no single stream of bytes
/// for a folder, and silently downloading only its first file would be worse
/// than not offering it.
Future<void> downloadNodes(
  BuildContext context,
  WidgetRef ref,
  List<NodeModel> nodes,
) async {
  final l10n = L10n.of(context);
  final files = nodes.where((node) => !node.isFolder).toList();
  if (files.isEmpty) {
    if (context.mounted) LdToast.show(context, message: l10n.downloadNoFiles);
    return;
  }

  await ref.read(transferControllerProvider.notifier).enqueueDownloads(
        <({String nodeId, String name, int sizeBytes})>[
          for (final node in files)
            (nodeId: node.id, name: node.name, sizeBytes: node.sizeBytes),
        ],
      );

  if (context.mounted) {
    LdToast.success(
      context,
      files.length == 1
          ? l10n.downloadQueuedOne(files.first.name)
          : l10n.downloadQueuedMany(files.length),
    );
  }
}
