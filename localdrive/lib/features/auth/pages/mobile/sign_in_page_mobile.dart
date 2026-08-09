import '../../../../imports.dart';
import '../../controller/session_controller.dart';

/// Sign in, and create account with an invite code. One screen with two modes,
/// because they are the same form with one extra field.
class SignInPageMobile extends HookConsumerWidget {
  const SignInPageMobile({super.key, this.createMode = false, this.inviteCode = ''});

  final bool createMode;

  /// pre-filled when someone arrived through an invite link or a scanned code
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

    return LdScaffold(
      actions: const <Widget>[LdLanguageToggle(compact: true)],
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding,
              vertical: 8,
            ),
            children: <Widget>[
              const SizedBox(height: 24),
              const Center(
                child: LdLogo(size: 76, stage: LdLogoStage.complete),
              ),
              const SizedBox(height: 26),
              Text(
                creating.value ? l10n.createAccountTitle : l10n.signInTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                creating.value
                    ? l10n.createAccountBody
                    : l10n.signInBody(
                        session.serverName.isEmpty
                            ? l10n.appName
                            : session.serverName,
                      ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (creating.value) ...<Widget>[
                LdTextField(
                  controller: invite,
                  label: l10n.inviteCodeLabel,
                  hint: l10n.inviteCodeHint,
                  prefixGlyph: LdGlyph.qr,
                  textAlign: TextAlign.center,
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
              if (needsTotp.value) ...<Widget>[
                const SizedBox(height: 16),
                LdTextField(
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
              ],
              const SizedBox(height: 28),
              LdButton(
                label: creating.value ? l10n.createAccount : l10n.signIn,
                busy: session.busy,
                onPressed: submit,
              ),
              const SizedBox(height: 16),
              // self registration is off by default, so the create account
              // path only offers itself when it can actually work
              if (creating.value || selfRegistration || inviteCode.isNotEmpty)
                Center(
                  child: LdButton.text(
                    label: creating.value
                        ? l10n.alreadyHaveAccount
                        : l10n.noAccountYet,
                    onPressed: () {
                      error.value = null;
                      creating.value = !creating.value;
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: LdButton.text(
                  label: l10n.settingsSwitchNode,
                  glyph: LdGlyph.server,
                  onPressed: () =>
                      ref.read(sessionProvider.notifier).switchNode(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
