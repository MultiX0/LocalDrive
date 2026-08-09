import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';
import '../../widgets/onboarding_desktop_shell.dart';

/// Step four on desktop, the first run branch: this node has no accounts, and
/// whoever completes this becomes its admin.
///
/// The desktop difference is real work, not spacing. The server name gets its
/// own labelled section, the two password fields sit on one row because a
/// window is wide enough to compare them at a glance, and the consequence of
/// this screen is stated in a notice rather than left in a help line, because
/// this is the one form in the app that can only ever be filled in once.
class SetupPageDesktop extends HookConsumerWidget {
  const SetupPageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final session = ref.watch(sessionProvider);

    final serverName = useTextEditingController(
      text: session.serverName.isEmpty ? l10n.appName : session.serverName,
    );
    final username = useTextEditingController();
    final password = useTextEditingController();
    final confirm = useTextEditingController();
    final error = useState<String?>(null);

    Future<void> submit() async {
      error.value = null;
      if (password.text != confirm.text) {
        error.value = l10n.passwordsDoNotMatch;
        return;
      }
      if (password.text.length < 10) {
        error.value = l10n.passwordTooShort;
        return;
      }
      try {
        await ref.read(sessionProvider.notifier).setup(
              username: username.text.trim(),
              password: password.text,
              serverName: serverName.text.trim(),
            );
      } on ApiException catch (failure) {
        error.value = failure.message;
      }
    }

    return OnboardingDesktopShell(
      step: OnboardingStep.account,
      title: l10n.setupTitle,
      subtitle: l10n.setupBody,
      onBack: () => context.go(Routes.language),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SectionLabel(l10n.serverNameLabel),
          LdTextField(
            controller: serverName,
            label: l10n.serverNameLabel,
            prefixGlyph: LdGlyph.server,
          ),
          const SizedBox(height: 28),
          _SectionLabel(l10n.setupAdminSection),
          LdTextField(
            controller: username,
            label: l10n.usernameLabel,
            hint: l10n.usernameHint,
            prefixGlyph: LdGlyph.person,
            autofillHints: const <String>[AutofillHints.newUsername],
          ),
          const SizedBox(height: 16),
          // side by side: a window is wide enough to compare the two at a
          // glance, which is the point of a confirm field
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: LdTextField(
                  controller: password,
                  label: l10n.passwordLabel,
                  hint: l10n.passwordHintNew,
                  obscure: true,
                  prefixGlyph: LdGlyph.lock,
                  helperText: l10n.passwordTooShort,
                  autofillHints: const <String>[AutofillHints.newPassword],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LdTextField(
                  controller: confirm,
                  label: l10n.confirmPasswordLabel,
                  hint: l10n.confirmPasswordHint,
                  obscure: true,
                  prefixGlyph: LdGlyph.lock,
                  errorText: error.value,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // this form runs exactly once in the life of a server, so say so
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LdColors.backgroundElevated,
              borderRadius: LdRadii.cardRadius,
              border: Border.all(color: LdColors.strokeOutline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const LdIcon(
                  LdGlyph.info,
                  size: 18,
                  color: LdColors.foregroundSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.setupOnceNotice,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: LdColors.foregroundSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LdButton(
              label: l10n.setUpThisServer,
              busy: session.busy,
              expand: false,
              onPressed: submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: LdColors.foregroundMuted,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
