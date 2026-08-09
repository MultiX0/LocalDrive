import '../../../../imports.dart';
import '../../../auth/controller/session_controller.dart';
import '../../widgets/onboarding_desktop_shell.dart';

/// Step three on desktop.
///
/// The phone stacks two radio rows because a thumb needs the height. A window
/// can put the two languages beside each other as full cards, each written in
/// its own script and previewing its own typeface, so the choice is made by
/// looking rather than by reading a label in a language you may not have.
class LanguagePageDesktop extends ConsumerWidget {
  const LanguagePageDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final current = ref.watch(localeProvider)?.languageCode ?? 'en';
    final session = ref.watch(sessionProvider);

    return OnboardingDesktopShell(
      step: OnboardingStep.language,
      title: l10n.languageTitle,
      onBack: () => context.go(Routes.connect),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _LanguageCard(
                  code: 'en',
                  nativeName: 'English',
                  sample: 'Your files, on your machine',
                  selected: current == 'en',
                  onTap: () =>
                      ref.read(localeProvider.notifier).set(const Locale('en')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LanguageCard(
                  code: 'ar',
                  nativeName: 'العربية',
                  sample: 'ملفاتك، على جهازك',
                  selected: current == 'ar',
                  onTap: () =>
                      ref.read(localeProvider.notifier).set(const Locale('ar')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LdButton(
              label: l10n.actionContinue,
              expand: false,
              onPressed: () {
                // a brand new node goes to setup, anything else to sign in
                final needsSetup = session.serverStatus?.setupRequired ?? false;
                context.go(needsSetup ? Routes.setup : Routes.signIn);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.code,
    required this.nativeName,
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String nativeName;

  /// a line of real copy in the language, rendered in that language's
  /// typeface, so the card previews the result of choosing it
  final String sample;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // resolved for the card's own language, not the app's current one, so the
    // card is a real preview of the face you get by choosing it
    final ownScale = LdTypography.forLanguage(code);

    return LdTappable(
      onTap: onTap,
      borderRadius: LdRadii.cardRadius,
      child: AnimatedContainer(
        duration: LdMotion.standard,
        curve: LdMotion.curve,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? LdColors.accentPrimary.withValues(alpha: 0.12)
              : LdColors.backgroundElevated,
          borderRadius: LdRadii.cardRadius,
          border: Border.all(
            color:
                selected ? LdColors.accentPrimary : LdColors.strokeOutline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Directionality(
          // each card renders in its own direction, not the app's current one
          textDirection:
              code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      nativeName,
                      style: ownScale.titleMedium!
                          .copyWith(color: LdColors.foregroundPrimary),
                    ),
                  ),
                  if (selected)
                    const LdIcon(
                      LdGlyph.check,
                      size: 18,
                      color: LdColors.accentPrimary,
                      mirrorInRtl: false,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                sample,
                style: ownScale.bodySmall!
                    .copyWith(color: LdColors.foregroundSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
