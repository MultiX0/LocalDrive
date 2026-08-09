import '../../../imports.dart';
import '../providers/storage_providers.dart';

/// Detected drives. One tap turns a recognized drive into a library, no
/// terminal involved. A drive with no filesystem this server can use offers
/// Format instead, behind the one guarded flow in the whole storage screen.
class DetectedDrives extends ConsumerWidget {
  const DetectedDrives({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final drives = ref.watch(drivesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(
            l10n.storageDetectedDrives.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        LdAsync<DriveList>(
          value: drives,
          compact: true,
          errorCopy: LdFormat.errorCopy(context),
          onRetry: () => ref.invalidate(drivesProvider),
          loading: const LdCardSkeleton(cards: 1),
          data: (list) {
            // a deployment without the mount helper is a supported choice, so
            // it says so plainly rather than showing a failure
            if (!list.helperAvailable) {
              return LdEmptyState(
                title: l10n.storageDetectedDrives,
                message: l10n.storageHelperUnavailable,
                glyph: LdGlyph.drive,
                compact: true,
              );
            }
            final available =
                list.drives.where((drive) => !drive.inUse).toList();
            if (available.isEmpty) {
              return LdEmptyState(
                title: l10n.storageDetectedDrives,
                message: l10n.emptyFolderBody,
                glyph: LdGlyph.drive,
                compact: true,
              );
            }
            return Column(
              children: <Widget>[
                for (final drive in available)
                  _DriveRow(drive: drive),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DriveRow extends ConsumerWidget {
  const _DriveRow({required this.drive});

  final DriveModel drive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    return LdNodeListItem(
      title: drive.displayName,
      subtitle:
          '${LdFormat.bytes(context, drive.sizeBytes)} ${drive.filesystem}',
      glyph: LdGlyph.drive,
      primaryAction: drive.usable
          ? LdButton(
              label: l10n.storageUseThisDrive,
              compact: true,
              onPressed: () async {
                await ref.read(storageDbProvider).mountDrive(
                      drive.id,
                      label: drive.displayName,
                    );
                ref.invalidate(librariesProvider);
                ref.invalidate(drivesProvider);
                if (context.mounted) {
                  LdToast.success(context, l10n.storageUseThisDrive);
                }
              },
            )
          : LdButton.destructive(
              label: l10n.storageFormat,
              compact: true,
              onPressed: () => _format(context, ref),
            ),
    );
  }

  /// The one destructive action in the storage flow, and it gets the friction
  /// it deserves: the phrase has to be typed exactly before the button works.
  Future<void> _format(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final confirmed = await LdBottomSheet.confirm(
      context,
      title: '${l10n.storageFormat} ${drive.displayName}',
      message: l10n.storageFormatWarning,
      confirmLabel: l10n.storageFormat,
      cancelLabel: l10n.actionCancel,
      destructive: true,
      requiredPhrase: l10n.storageFormatPhrase,
      phraseHint: l10n.storageFormatPhraseHint,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(storageDbProvider).formatDrive(
          drive.id,
          confirmation: l10n.storageFormatPhrase,
          label: drive.displayName,
        );
    ref.invalidate(drivesProvider);
    if (context.mounted) LdToast.success(context, l10n.storageFormat);
  }
}
