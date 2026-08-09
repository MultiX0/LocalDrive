import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';
import '../../providers/storage_providers.dart';
import '../../widgets/detected_drives.dart';
import '../../widgets/library_card.dart';
import '../../widgets/storage_total_card.dart';

/// Storage, on a phone: one column, totals first, then a card per library,
/// then the detected drives.
class StoragePageMobile extends ConsumerWidget {
  const StoragePageMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final libraries = ref.watch(librariesProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Column(
      children: <Widget>[
        // reached from Settings, and the tab bar is hidden here, so this is
        // the way back
        LdPageHeader(
          title: l10n.storage,
          onBack: () => context.go(Routes.settings),
        ),
        Expanded(
          child: LdRefresh(
            onRefresh: () async {
              ref.invalidate(librariesProvider);
              ref.invalidate(drivesProvider);
              await ref.read(librariesProvider.future);
            },
            child: LdAsync<LibrarySummary>(
              value: libraries,
              errorCopy: LdFormat.errorCopy(context),
              onRetry: () => ref.invalidate(librariesProvider),
              loading: const LdCardSkeleton(),
              data: (summary) => ListView(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  0,
                  context.pagePadding,
                  120,
                ),
                children: <Widget>[
                  StorageTotalCard(summary: summary),
                  const SizedBox(height: 20),
                  for (final library in summary.libraries)
                    LibraryCard(library: library, isAdmin: isAdmin),
                  if (isAdmin) ...<Widget>[
                    const SizedBox(height: 12),
                    const DetectedDrives(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
