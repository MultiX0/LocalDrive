import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';
import '../../auth/models/user_model.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<SessionModel>>((ref) {
  return ref.watch(authDbProvider).sessions();
});

final _pendingProvider = FutureProvider.autoDispose<List<SessionModel>>((ref) {
  return ref.watch(authDbProvider).pendingDevices();
});

/// Devices and sessions, with the pending section on top when there is one.
///
/// Approving is self service: a device already on the account lets a new one
/// in, without needing the admin at all.
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final sessions = ref.watch(_sessionsProvider);
    final pending = ref.watch(_pendingProvider);

    return LdRefresh(
      onRefresh: () async {
        ref.invalidate(_sessionsProvider);
        ref.invalidate(_pendingProvider);
        await ref.read(_sessionsProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          16,
          context.pagePadding,
          120,
        ),
        children: <Widget>[
          pending.maybeWhen(
            data: (devices) {
              if (devices.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.devicesPendingSection.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  for (final device in devices)
                    LdNodeListItem(
                      title: device.deviceName,
                      subtitle: '${device.platform} ${device.ip}',
                      glyph: LdGlyph.device,
                      status: l10n.pendingApproval,
                      statusColor: LdColors.filePresentation,
                      primaryAction: LdButton(
                        label: l10n.approve,
                        compact: true,
                        onPressed: () async {
                          await ref
                              .read(authDbProvider)
                              .approveDevice(device.id);
                          ref.invalidate(_pendingProvider);
                          ref.invalidate(_sessionsProvider);
                          if (context.mounted) {
                            LdToast.success(
                              context,
                              l10n.devicesApprovedToast,
                            );
                          }
                        },
                      ),
                      secondaryAction: LdButton.secondary(
                        label: l10n.deny,
                        compact: true,
                        onPressed: () async {
                          await ref.read(authDbProvider).denyDevice(device.id);
                          ref.invalidate(_pendingProvider);
                          if (context.mounted) {
                            LdToast.show(
                              context,
                              message: l10n.devicesDeniedToast,
                            );
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          LdAsync<List<SessionModel>>(
            value: sessions,
            errorCopy: LdFormat.errorCopy(context),
            onRetry: () => ref.invalidate(_sessionsProvider),
            loading: const LdListSkeleton(rows: 3, padding: EdgeInsets.zero),
            isEmpty: (list) => list.isEmpty,
            empty: () => LdEmptyState(
              title: l10n.emptyDevicesTitle,
              glyph: LdGlyph.device,
              compact: true,
            ),
            data: (list) => Column(
              children: <Widget>[
                for (final device in list.where((s) => !s.isPending))
                  LdNodeListItem(
                    title: device.deviceName,
                    subtitle: l10n.devicesLastSeen(
                      LdFormat.relative(context, device.lastSeenAt),
                    ),
                    glyph: LdGlyph.device,
                    status: device.current ? l10n.devicesThisDevice : null,
                    statusColor: LdColors.accentPrimary,
                    primaryAction: device.current
                        ? null
                        : LdButton.secondary(
                            label: l10n.devicesRevoke,
                            compact: true,
                            onPressed: () async {
                              await ref
                                  .read(authDbProvider)
                                  .revokeSession(device.id);
                              ref.invalidate(_sessionsProvider);
                            },
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
