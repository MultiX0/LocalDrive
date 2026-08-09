import '../../../imports.dart';
import '../../upload/controller/transfer_controller.dart';

/// The persistent uploads tray: dismissible, but not losable.
///
/// It shows aggregate state, and tapping it opens the full queue where a
/// failed item shows its specific reason and its own retry, never a generic
/// "something went wrong" covering the whole batch.
class UploadsTray extends ConsumerWidget {
  const UploadsTray({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    // watching only the summary keeps every progress tick from rebuilding the
    // screen behind it
    final summary = ref.watch(transferSummaryProvider);
    if (summary.isEmpty) return const SizedBox.shrink();

    final done = summary.completed == summary.total && !summary.needsAttention;
    if (done) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LdTappable(
        onTap: () => context.push(Routes.transfers),
        borderRadius: LdRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LdColors.backgroundElevated,
            borderRadius: LdRadii.cardRadius,
            border: Border.all(
              color: summary.needsAttention
                  ? LdColors.accentWarning
                  : LdColors.strokeOutline,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  LdIcon(
                    summary.needsAttention ? LdGlyph.warning : LdGlyph.upload,
                    size: 18,
                    color: summary.needsAttention
                        ? LdColors.accentWarning
                        : LdColors.accentPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.transfersSummary(summary.completed, summary.total),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const LdIcon(
                    LdGlyph.chevronRight,
                    size: 16,
                    color: LdColors.foregroundSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LdProgressBar(
                value: summary.progress,
                color: summary.needsAttention
                    ? LdColors.accentWarning
                    : LdColors.accentPrimary,
              ),
              if (summary.needsAttention) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  l10n.transfersNeedAttention(summary.failed),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: LdColors.accentWarning,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
