import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';
import '../../providers/storage_providers.dart';
import '../../widgets/detected_drives.dart';
import '../../widgets/library_card.dart';
import '../../widgets/storage_total_card.dart';

/// Storage, on desktop. A wide window fits the libraries beside the detected
/// drives instead of stacking them, which is the whole reason to have a
/// separate layout rather than a wider phone.
class StoragePageDesktop extends ConsumerWidget {
  const StoragePageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final libraries = ref.watch(librariesProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return LdDesktopScaffold(
      title: l10n.storage,
      actions: <Widget>[
        LdUtilityButton(
          glyph: LdGlyph.refresh,
          tooltip: l10n.actionRefresh,
          onPressed: () {
            ref.invalidate(librariesProvider);
            ref.invalidate(drivesProvider);
          },
        ),
      ],
      body: LdAsync<LibrarySummary>(
        value: libraries,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(librariesProvider),
        loading: const LdCardSkeleton(),
        data: (summary) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StorageTotalCard(summary: summary),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final library in summary.libraries)
                          LibraryCard(library: library, isAdmin: isAdmin),
                      ],
                    ),
                  ),
                  if (isAdmin) ...<Widget>[
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: DetectedDrives()),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
