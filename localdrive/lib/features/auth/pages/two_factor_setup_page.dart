import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../imports.dart';
import '../controller/session_controller.dart';

/// Setting up two factor.
///
/// The QR is shown first because that is the path almost everybody takes: open
/// the authenticator, point it at the screen, done. The secret is underneath
/// for anyone typing it into a password manager or setting up a device that
/// cannot see this screen.
///
/// Nothing is enabled until a real code from the app is accepted. An account
/// cannot end up half enrolled and locked out of itself.
class TwoFactorSetupPage extends HookConsumerWidget {
  const TwoFactorSetupPage({
    super.key,
    this.required = false,
    this.embedded = false,
  });

  /// True when this is shown inside the settings shell, which already draws a
  /// header. Without it the screen stacked its own title on top of the shell's
  /// and the account got two identical app bars.
  final bool embedded;

  /// An admin has to finish this; there is no skip. A member opened it from
  /// settings and can leave.
  final bool required;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final code = useTextEditingController();
    final typed = useValueListenable(code);
    final enrollment = ref.watch(totpEnrollmentProvider);
    final busy = useState(false);
    final error = useState<String?>(null);

    final alreadyOn = ref.watch(currentUserProvider)?.totpEnabled ?? false;

    // scanning is what almost everyone does, so that is what is on screen
    final byHand = useState(false);

    Future<void> confirm() async {
      busy.value = true;
      error.value = null;
      try {
        await ref
            .read(sessionProvider.notifier)
            .confirmTwoFactor(code.text.trim());
        if (context.mounted) {
          LdToast.success(context, l10n.twoFactorOn);
          if (!required) Navigator.of(context).maybePop();
        }
      } on ApiException catch (failure) {
        error.value = failure.message;
      } finally {
        busy.value = false;
      }
    }

    // Enrolment only makes sense for an account that is not enrolled. Asking
    // the server to begin again for one that is returns an error, which is why
    // opening this from settings on an enrolled account showed "Something went
    // wrong" rather than telling anyone the plain truth: it is already on.
    if (alreadyOn) {
      final done = _AlreadyOn(embedded: embedded);
      return embedded
          ? done
          : LdScaffold(
              title: l10n.twoFactorTitle,
              showBack: !required,
              body: done,
            );
    }

    final body = LdAsync<TotpEnrollment>(
        value: enrollment,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(totpEnrollmentProvider),
        // a six digit field and a QR code do not want a 1440 pixel window, so
        // the whole step column keeps a form's width and centres
        data: (data) {
          // The two halves of enrolling: put it in the app, then prove it took.
          // On a phone they can only stack. On a tablet or a desktop they sit
          // side by side, because the whole point of the screen is reading a
          // code off one panel and typing it into the other, and making someone
          // scroll between the two is what made this read as a phone screen
          // somebody had stretched.
          final intro = Text(
            required ? l10n.twoFactorRequiredBody : l10n.twoFactorOptionalBody,
            style: Theme.of(context).textTheme.bodyMedium,
          );

          final panel = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Step(number: 1, title: l10n.twoFactorScanTitle),
              const SizedBox(height: 12),
              LdSegmented<bool>(
                selected: byHand.value,
                onChanged: (next) => byHand.value = next,
                segments: <bool, String>{
                  false: l10n.twoFactorUseQr,
                  true: l10n.twoFactorUseKey,
                },
              ),
              const SizedBox(height: 16),
              if (!byHand.value)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(LdRadii.card),
                    ),
                    child: QrImageView(
                      data: data.otpauthUrl,
                      size: 200,
                      backgroundColor: Colors.white,
                      gapless: true,
                    ),
                  ),
                )
              else ...<Widget>[
                Text(
                  l10n.twoFactorKeyBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _CopyRow(value: data.secret, label: l10n.actionCopyCode),
              ],
            ],
          );

          final proof = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Step(number: 2, title: l10n.twoFactorConfirmTitle),
              const SizedBox(height: 12),
              LdTextField(
                controller: code,
                label: l10n.twoFactorCode,
                hint: l10n.twoFactorCodeHint,
                keyboardType: TextInputType.number,
                prefixGlyph: LdGlyph.lock,
                errorText: error.value,
                onSubmitted: (_) => confirm(),
              ),
              const SizedBox(height: 16),
              LdButton(
                label: l10n.twoFactorTurnOn,
                busy: busy.value,
                onPressed: typed.text.trim().length < 6 ? null : confirm,
              ),
              if (data.recoveryCodes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _RecoveryCodes(codes: data.recoveryCodes),
              ],
            ],
          );

          if (context.deviceClass == DeviceClass.mobile) {
            return ListView(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              children: <Widget>[
                const SizedBox(height: 8),
                intro,
                const SizedBox(height: 24),
                panel,
                const SizedBox(height: 28),
                proof,
                const SizedBox(height: 32),
              ],
            );
          }

          return LdContentPane(
            maxWidth: LdContentPane.list,
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
              children: <Widget>[
                const SizedBox(height: 12),
                intro,
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: panel),
                    const SizedBox(width: 40),
                    Expanded(child: proof),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
    );

    if (embedded) return body;
    return LdScaffold(
      title: l10n.twoFactorTitle,
      showBack: !required,
      body: body,
    );
  }
}

/// What an already enrolled account sees.
class _AlreadyOn extends StatelessWidget {
  const _AlreadyOn({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.pagePadding),
        child: LdEmptyState(
          glyph: LdGlyph.lock,
          title: l10n.twoFactorOn,
          message: l10n.twoFactorAlreadyOnBody,
          compact: true,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: LdColors.accentPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: LdColors.foregroundPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: LdColors.backgroundSunken,
        borderRadius: BorderRadius.circular(LdRadii.field),
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                letterSpacing: 1.2,
                fontFamily: 'monospace',
                color: LdColors.foregroundPrimary,
              ),
            ),
          ),
          LdButton.text(
            label: label,
            glyph: LdGlyph.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              LdToast.success(context, L10n.of(context).actionCopied);
            },
          ),
        ],
      ),
    );
  }
}

class _RecoveryCodes extends StatelessWidget {
  const _RecoveryCodes({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: BorderRadius.circular(LdRadii.card),
        border: Border.all(color: LdColors.accentWarning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const LdIcon(
                LdGlyph.warning,
                size: 18,
                color: LdColors.accentWarning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.recoveryCodesTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.recoveryCodesBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              for (final recovery in codes)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LdColors.backgroundSunken,
                    borderRadius: BorderRadius.circular(LdRadii.chip),
                  ),
                  child: SelectableText(
                    recovery,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      color: LdColors.foregroundPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LdButton.secondary(
            label: l10n.actionCopy,
            glyph: LdGlyph.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codes.join('\n')));
              LdToast.success(context, l10n.actionCopied);
            },
          ),
        ],
      ),
    );
  }
}
