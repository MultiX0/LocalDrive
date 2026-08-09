import '../../../imports.dart';
import '../controller/session_controller.dart';

/// The forced, unskippable password change.
///
/// While the account carries a temporary credential the server refuses every
/// write, so this screen is the only way forward. A default password can exist
/// for a few minutes at most, never indefinitely by accident.
class ChangePasswordPage extends HookConsumerWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final session = ref.watch(sessionProvider);

    final current = useTextEditingController();
    final next = useTextEditingController();
    final confirm = useTextEditingController();
    final error = useState<String?>(null);

    Future<void> submit() async {
      error.value = null;
      if (next.text != confirm.text) {
        error.value = l10n.passwordsDoNotMatch;
        return;
      }
      if (next.text.length < 10) {
        error.value = l10n.passwordTooShort;
        return;
      }
      try {
        await ref.read(sessionProvider.notifier).changePassword(
              currentPassword: current.text,
              newPassword: next.text,
            );
        if (context.mounted) LdToast.success(context, l10n.passwordChanged);
      } on ApiException catch (failure) {
        error.value = failure.message;
      }
    }

    return LdScaffold(
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
              const SizedBox(height: 40),
              const Center(child: LdIcon(LdGlyph.lock, size: 44)),
              const SizedBox(height: 26),
              Text(
                l10n.mustChangePasswordTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.mustChangePasswordBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              LdTextField(
                controller: current,
                label: l10n.currentPassword,
                hint: l10n.passwordHintExisting,
                obscure: true,
                prefixGlyph: LdGlyph.lock,
              ),
              const SizedBox(height: 16),
              LdTextField(
                controller: next,
                label: l10n.newPassword,
                hint: l10n.passwordHintNew,
                obscure: true,
                prefixGlyph: LdGlyph.lock,
                helperText: l10n.passwordTooShort,
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
                label: l10n.actionSave,
                busy: session.busy,
                onPressed: submit,
              ),
              const SizedBox(height: 16),
              Center(
                child: LdButton.text(
                  label: l10n.settingsSignOut,
                  glyph: LdGlyph.logout,
                  onPressed: () => ref.read(sessionProvider.notifier).signOut(),
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
