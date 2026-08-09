import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';
import '../../files/controller/files_controller.dart';
import '../../offline/controller/offline_controller.dart';
import '../../storage/providers/storage_providers.dart';

/// One listener for the whole app turns live events into cache invalidations
/// and toasts, so no page has to subscribe itself.
///
/// It uses ref.listen rather than watch, because reacting to a change without
/// rendering it belongs in a side effect, not in a build.
class LiveEventListener extends ConsumerWidget {
  const LiveEventListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // the offline controller has to exist for its reconnect listener to fire.
    // Nothing renders it, so it is kept alive from here rather than only
    // waking up the first time someone opens the downloads panel
    ref.watch(offlineControllerProvider);

    ref.listen(eventStreamProvider, (previous, next) {
      next.whenData((event) => _handle(context, ref, event));
    });

    // a reconnect refetches, since events may have been missed while the
    // socket was down
    ref.listen(reconnectedProvider, (previous, next) {
      next.whenData((_) {
        ref.read(filesControllerProvider.notifier).reconcile();
        ref.invalidate(librariesProvider);
      });
    });

    return child;
  }

  void _handle(BuildContext context, WidgetRef ref, LdEvent event) {
    final files = ref.read(filesControllerProvider.notifier);

    switch (event.type) {
      case WsEvents.nodeCreated:
      case WsEvents.nodeUpdated:
      case WsEvents.nodeMoved:
      case WsEvents.nodeDeleted:
      case WsEvents.nodeRestored:
      case WsEvents.thumbnailReady:
        // a badge-only tile swaps for its real thumbnail without a refresh
        files.applyRemoteChange(
          parentId: event.parentId ?? '',
          nodeId: event.nodeId,
        );

      case WsEvents.quotaUpdated:
        ref.read(sessionProvider.notifier).applyQuota(
              quotaBytes: event.payload['quota_bytes'] as int? ?? 0,
              quotaBytesUsed: event.payload['quota_bytes_used'] as int? ?? 0,
            );

      case WsEvents.shareReceived:
        // the receiving side gets the sender's face and the item's own icon,
        // which is the other half of the send animation
        _showReceived(context, event);
        files.applyRemoteChange();

      case WsEvents.devicePending:
        final l10n = L10n.of(context);
        final device = event.payload['device_name'] as String? ?? '';
        LdToast.show(
          context,
          message: '${l10n.pendingApproval} $device',
          kind: LdToastKind.warning,
          actionLabel: l10n.devices,
          onAction: () => context.go(Routes.settingsDevices),
        );

      case WsEvents.deviceApproved:
        LdToast.success(context, L10n.of(context).deviceApproved);

      case WsEvents.libraryChanged:
        ref.invalidate(librariesProvider);

      case WsEvents.sessionRevoked:
        // the api client raises its own session lost signal for the token that
        // stops working; this only matters when another device was revoked
        ref.read(sessionProvider.notifier).refreshUser();
    }
  }
}


/// The card that slides in when someone shares something with this device.
void _showReceived(BuildContext context, LdEvent event) {
  final l10n = L10n.of(context);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final sender = event.payload['owner_name'] as String? ?? '';
  final seed = event.payload['owner_id'] as String? ?? sender;
  final itemName = event.payload['node_name'] as String? ?? '';
  final isFolder = event.payload['node_type'] == 'folder';

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 16,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LdReceivedCard(
              senderName: sender.isEmpty ? l10n.sharedWithMe : sender,
              senderSeed: seed,
              itemName: itemName,
              glyph: isFolder ? LdGlyph.folder : LdGlyph.file,
              openLabel: l10n.actionOpen,
              onOpen: () {
                entry.remove();
                context.go(Routes.shared);
              },
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 5), () {
    if (entry.mounted) entry.remove();
  });
}
