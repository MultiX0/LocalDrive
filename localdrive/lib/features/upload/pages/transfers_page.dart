import '../../../imports.dart';
import '../controller/transfer_controller.dart';
import '../models/transfer_model.dart';

/// The full queue. A failed item shows its own specific reason and its own
/// retry, never a generic message covering the whole batch.
class TransfersPage extends ConsumerWidget {
  const TransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final transfers = ref.watch(transferControllerProvider);
    final summary = ref.watch(transferSummaryProvider);
    final controller = ref.read(transferControllerProvider.notifier);

    return LdScaffold(
      showBack: true,
      title: l10n.transfersTitle,
      subtitle: summary.isEmpty
          ? null
          : l10n.transfersSummary(summary.completed, summary.total),
      actions: <Widget>[
        if (summary.needsAttention)
          LdUtilityButton(
            glyph: LdGlyph.refresh,
            tooltip: l10n.transferRetry,
            onPressed: controller.retryAll,
          ),
        if (summary.completed > 0)
          LdUtilityButton(
            glyph: LdGlyph.check,
            tooltip: l10n.actionDone,
            onPressed: controller.clearCompleted,
          ),
      ],
      body: transfers.isEmpty
          ? LdEmptyState(
              title: l10n.emptyTransfersTitle,
              message: l10n.emptyTransfersBody,
              glyph: LdGlyph.upload,
            )
          : LdContentPane(
              maxWidth: LdContentPane.list,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  8,
                  context.pagePadding,
                  40,
                ),
                itemCount: transfers.length,
                itemBuilder: (context, index) => _TransferRow(
                  transfer: transfers[index],
                  onRetry: () => controller.retry(transfers[index].id),
                  onCancel: () => controller.cancel(transfers[index].id),
                ),
              ),
            ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.transfer,
    required this.onRetry,
    required this.onCancel,
  });

  final TransferModel transfer;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final failed = transfer.status == TransferStatus.failed;
    final done = transfer.status == TransferStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.tileRadius,
        border: Border.all(
          color: failed ? LdColors.accentWarning : LdColors.strokeOutline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              LdIcon(
                switch (transfer.status) {
                  TransferStatus.completed => LdGlyph.check,
                  TransferStatus.failed => LdGlyph.warning,
                  TransferStatus.paused => LdGlyph.offline,
                  _ =>
                    transfer.kind == TransferKind.upload
                        ? LdGlyph.upload
                        : LdGlyph.download,
                },
                size: 18,
                color: failed
                    ? LdColors.accentWarning
                    : done
                    ? LdColors.fileSpreadsheet
                    : LdColors.accentPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transfer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLine(context),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: failed
                            ? LdColors.accentWarning
                            : LdColors.foregroundSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (failed)
                LdButton.text(label: l10n.transferRetry, onPressed: onRetry)
              else if (!done)
                LdTappable(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(18),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: LdIcon(
                      LdGlyph.close,
                      size: 16,
                      color: LdColors.foregroundSecondary,
                    ),
                  ),
                ),
            ],
          ),
          if (!done) ...<Widget>[
            const SizedBox(height: 12),
            LdProgressBar(
              value: transfer.progress,
              indeterminate: transfer.status == TransferStatus.retrying,
              color: failed ? LdColors.accentWarning : LdColors.accentPrimary,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLine(BuildContext context) {
    final l10n = L10n.of(context);
    if (transfer.status == TransferStatus.failed) {
      return transfer.failureMessage.isEmpty
          ? l10n.transferFailed
          : transfer.failureMessage;
    }
    // a finished download says where it landed, because "done" with no
    // location just makes someone go looking for it
    if (transfer.status == TransferStatus.completed &&
        transfer.savedTo.isNotEmpty) {
      return l10n.downloadSavedTo(transfer.savedTo);
    }
    final label = switch (transfer.status) {
      TransferStatus.queued => l10n.transferQueued,
      TransferStatus.inProgress => l10n.transferInProgress,
      TransferStatus.retrying => l10n.transferRetrying,
      TransferStatus.paused => l10n.transferPausedOffline,
      TransferStatus.completed => l10n.transferCompleted,
      TransferStatus.failed => l10n.transferFailed,
    };
    if (transfer.totalBytes <= 0) return label;
    return '$label  '
        '${LdFormat.bytes(context, transfer.transferredBytes)} / '
        '${LdFormat.bytes(context, transfer.totalBytes)}';
  }
}
