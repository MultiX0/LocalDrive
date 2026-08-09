import '../../../../imports.dart';
import '../../../onboarding/widgets/onboarding_desktop_shell.dart';
import '../../controller/session_controller.dart';

/// Sign in, on desktop.
///
/// Two differences from the phone that are behaviour, not layout. The node you
/// are signing in to is named in a header strip with the way to change it right
/// there, because on a computer people genuinely run more than one server and
/// the phone hides that behind a small text button at the bottom. And the
/// second factor field appears in place with the form still visible, so a
/// password manager that just filled the form does not lose it.
class SignInPageDesktop extends HookConsumerWidget {
  const SignInPageDesktop({
    super.key,
    this.createMode = false,
    this.inviteCode = '',
  });

  final bool createMode;
  final String inviteCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final session = ref.watch(sessionProvider);
    final creating = useState(createMode);

    final username = useTextEditingController();
    final password = useTextEditingController();
    final invite = useTextEditingController(text: inviteCode);
    final totp = useTextEditingController();
    final needsTotp = useState(false);
    final error = useState<String?>(null);

    Future<void> submit() async {
      error.value = null;
      try {
        if (creating.value) {
          await ref.read(sessionProvider.notifier).register(
                username: username.text.trim(),
                password: password.text,
                inviteCode: invite.text.trim(),
              );
        } else {
          await ref.read(sessionProvider.notifier).signIn(
                username: username.text.trim(),
                password: password.text,
                totpCode: totp.text.trim(),
              );
        }
      } on ApiException catch (failure) {
        if (failure.code == 'totp_required') {
          needsTotp.value = true;
          error.value = null;
          return;
        }
        error.value = failure.message;
      }
    }

    final selfRegistration =
        session.serverStatus?.allowSelfRegistration ?? false;

    return OnboardingDesktopShell(
      step: OnboardingStep.account,
      title: creating.value ? l10n.createAccountTitle : l10n.signInTitle,
      subtitle: creating.value ? l10n.createAccountBody : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // which server this is, and how to leave it, stated rather than
          // buried in a text button under the fold
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: LdColors.backgroundElevated,
              borderRadius: LdRadii.cardRadius,
              border: Border.all(color: LdColors.strokeOutline),
            ),
            child: Row(
              children: <Widget>[
                const LdIcon(
                  LdGlyph.server,
                  size: 18,
                  color: LdColors.accentPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.serverName.isEmpty
                        ? l10n.appName
                        : session.serverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                LdButton.text(
                  label: l10n.settingsSwitchNode,
                  onPressed: () =>
                      ref.read(sessionProvider.notifier).switchNode(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (creating.value) ...<Widget>[
            LdTextField(
              controller: invite,
              label: l10n.inviteCodeLabel,
              hint: l10n.inviteCodeHint,
              prefixGlyph: LdGlyph.qr,
            ),
            const SizedBox(height: 16),
          ],
          LdTextField(
            controller: username,
            label: l10n.usernameLabel,
            hint: l10n.usernameHint,
            prefixGlyph: LdGlyph.person,
            autofillHints: <String>[
              creating.value
                  ? AutofillHints.newUsername
                  : AutofillHints.username,
            ],
          ),
          const SizedBox(height: 16),
          LdTextField(
            controller: password,
            label: l10n.passwordLabel,
            hint: creating.value ? l10n.passwordHintNew : l10n.passwordHintExisting,
            obscure: true,
            prefixGlyph: LdGlyph.lock,
            errorText: needsTotp.value ? null : error.value,
            textInputAction:
                needsTotp.value ? TextInputAction.next : TextInputAction.go,
            autofillHints: <String>[
              creating.value
                  ? AutofillHints.newPassword
                  : AutofillHints.password,
            ],
            onSubmitted: (_) => needsTotp.value ? null : submit(),
          ),
          // in place, with the filled form still on screen
          AnimatedSize(
            duration: LdMotion.standard,
            curve: LdMotion.curve,
            alignment: Alignment.topCenter,
            child: needsTotp.value
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: LdTextField(
                      controller: totp,
                      label: l10n.twoFactorCode,
                      hint: l10n.twoFactorCodeHint,
                      helperText: l10n.twoFactorHint,
                      errorText: error.value,
                      keyboardType: TextInputType.number,
                      prefixGlyph: LdGlyph.lock,
                      autofocus: true,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => submit(),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 28),
          Row(
            children: <Widget>[
              LdButton(
                label: creating.value ? l10n.createAccount : l10n.signIn,
                busy: session.busy,
                expand: false,
                onPressed: submit,
              ),
              const SizedBox(width: 12),
              // self registration is off by default, so the create account
              // path only offers itself when it can actually work
              if (creating.value || selfRegistration || inviteCode.isNotEmpty)
                LdButton.text(
                  label: creating.value
                      ? l10n.alreadyHaveAccount
                      : l10n.noAccountYet,
                  onPressed: () {
                    error.value = null;
                    creating.value = !creating.value;
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
