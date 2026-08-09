import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';

/// The first run branch: this node has zero accounts, and whoever completes
/// this becomes its admin. It is the one screen that creates an account with
/// no invite, and the server refuses it the moment a single user exists.
class SetupPageMobile extends HookConsumerWidget {
  const SetupPageMobile({super.key});

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

    return LdScaffold(
      showBack: true,
      onBack: () => context.go(Routes.language),
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
              const Center(
                child: LdLogo(size: 76, stage: LdLogoStage.complete),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.setupTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.setupBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              LdTextField(
                controller: serverName,
                label: l10n.serverNameLabel,
                prefixGlyph: LdGlyph.server,
              ),
              const SizedBox(height: 16),
              LdTextField(
                controller: username,
                label: l10n.usernameLabel,
                hint: l10n.usernameHint,
                prefixGlyph: LdGlyph.person,
                autofillHints: const <String>[AutofillHints.newUsername],
              ),
              const SizedBox(height: 16),
              LdTextField(
                controller: password,
                label: l10n.passwordLabel,
                hint: l10n.passwordHintNew,
                obscure: true,
                prefixGlyph: LdGlyph.lock,
                helperText: l10n.passwordTooShort,
                autofillHints: const <String>[AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              LdTextField(
                controller: confirm,
                label: l10n.confirmPasswordLabel,
                hint: l10n.confirmPasswordHint,
                obscure: true,
                prefixGlyph: LdGlyph.lock,
                errorText: error.value,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 28),
              LdButton(
                label: l10n.setUpThisServer,
                busy: session.busy,
                onPressed: submit,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
