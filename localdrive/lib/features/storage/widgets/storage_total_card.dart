import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';
import '../providers/storage_providers.dart';

/// What is on the drives, shown above the per library cards.
///
/// The headline number is the signed in account's own files, not the server's.
/// A member seeing the server total would be reading how much everyone else
/// stores, and on a family server that is not theirs to see. Free space is the
/// exception and stays device wide, because the disk really is shared and
/// knowing your own usage tells you nothing about whether there is room.
///
/// An admin gets the server wide figure, because running the box is the job.
class StorageTotalCard extends ConsumerWidget {
  const StorageTotalCard({super.key, required this.summary});

  final LibrarySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final isAdmin = ref.watch(isAdminProvider);
    final user = ref.watch(currentUserProvider);

    final used = isAdmin || user == null
        ? summary.totalUsed
        : user.quotaBytesUsed;
    final caption = isAdmin || user == null ? l10n.storageTotal : l10n.storageYours;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.cardRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(caption, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Text(
            LdFormat.bytes(context, used),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 16),
          LdUsageBar(
            usedBytes: used,
            totalBytes: summary.totalBytes,
            usedLabel: l10n.storageUsedOf(
              LdFormat.bytes(context, used),
              LdFormat.bytes(context, summary.totalBytes),
            ),
            freeLabel: l10n.libraryFreeSpace(
              LdFormat.bytes(context, summary.totalFree),
            ),
          ),
        ],
      ),
    );
  }
}
