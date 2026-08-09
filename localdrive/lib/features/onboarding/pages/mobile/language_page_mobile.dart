import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';

/// Step three. Picking a language here also proves the typeface swap works
/// before anything else in the app depends on it.
class LanguagePageMobile extends ConsumerWidget {
  const LanguagePageMobile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final current = ref.watch(localeProvider);
    final session = ref.watch(sessionProvider);

    Future<void> choose(String code) async {
      await ref.read(localeProvider.notifier).set(Locale(code));
    }

    return LdScaffold(
      showBack: true,
      onBack: () => context.go(Routes.connect),
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
                const Center(
                  child: LdLogo(size: 84, stage: LdLogoStage.syncing),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.languageTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 28),
                LdRadioRow(
                  label: l10n.languageEnglish,
                  selected: (current?.languageCode ?? 'en') == 'en',
                  onTap: () => choose('en'),
                ),
                LdRadioRow(
                  label: l10n.languageArabic,
                  selected: current?.languageCode == 'ar',
                  onTap: () => choose('ar'),
                ),
                const SizedBox(height: 24),
                LdButton(
                  label: l10n.actionContinue,
                  onPressed: () {
                    // a brand new node goes to setup, anything else to sign in
                    final needsSetup =
                        session.serverStatus?.setupRequired ?? false;
                    context.go(needsSetup ? Routes.setup : Routes.signIn);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
