import '../../../imports.dart';
import '../providers/activity_providers.dart';

/// The audit trail. A member sees their own rows; an admin can widen it to the
/// whole server, which is metadata only and never file contents.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final entries = ref.watch(activityProvider);

    return LdContentPane(
      maxWidth: LdContentPane.list,
      child: Column(
        children: <Widget>[
          // opened from Settings, so it carries its own way back
          LdPageHeader(
            title: l10n.activity,
            onBack: () => context.go(Routes.settings),
          ),
          Expanded(
            child: LdRefresh(
              onRefresh: () async {
                ref.invalidate(activityProvider);
                await ref.read(activityProvider.future);
              },
              child: LdAsync<List<ActivityEntry>>(
                value: entries,
                errorCopy: LdFormat.errorCopy(context),
                onRetry: () => ref.invalidate(activityProvider),
                loading: const LdListSkeleton(),
                isEmpty: (list) => list.isEmpty,
                empty: () => LdEmptyState(
                  title: l10n.emptyActivityTitle,
                  glyph: LdGlyph.activity,
                ),
                data: (list) => ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    8,
                    context.pagePadding,
                    120,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _ActivityRow(entry: list[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: LdColors.wash(entry.tint, 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: LdIcon(entry.glyph, size: 17, color: entry.tint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.describe(context),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  LdFormat.relative(context, entry.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
