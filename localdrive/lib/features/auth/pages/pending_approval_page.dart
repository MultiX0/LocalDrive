import '../../../imports.dart';
import '../controller/session_controller.dart';

/// The waiting screen for a device held for approval.
///
/// It is a dedicated, branded screen rather than a spinner pretending to be a
/// normal load, because this is not a load: something has to happen on another
/// device before this one goes anywhere.
class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final session = ref.watch(sessionProvider);
    final denied = session.error is ApiException &&
        (session.error! as ApiException).code == 'device_denied';

    return LdScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // the mark at rest, not a spinner
                const Center(
                  child: LdLogo(
                    size: 96,
                    stage: LdLogoStage.connected,
                    animate: false,
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  denied ? l10n.deviceDeniedTitle : l10n.waitingForApprovalTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  denied
                      ? l10n.deviceDeniedBody
                      : l10n.waitingForApprovalBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: LdColors.foregroundSecondary,
                      ),
                ),
                const SizedBox(height: 32),
                if (!denied) ...<Widget>[
                  const Center(child: LdSpinner(size: 26)),
                  const SizedBox(height: 32),
                ],
                LdButton.secondary(
                  label: denied ? l10n.actionRetry : l10n.actionCancel,
                  onPressed: () =>
                      ref.read(sessionProvider.notifier).cancelPendingApproval(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
