import '../../../../imports.dart';

/// Step one on a phone: one column, the mark at rest, one action.
///
/// The language switch sits on this screen rather than a step further in.
/// Someone who does not read the welcome copy cannot be expected to navigate
/// three screens in a language they do not speak to reach it.
class WelcomePageMobile extends StatelessWidget {
  const WelcomePageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

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
                const Center(
                  child: LdLogo(size: 112, stage: LdLogoStage.closed),
                ),
                const SizedBox(height: 44),
                Text(
                  l10n.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.welcomeBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: LdColors.foregroundSecondary,
                      ),
                ),
                const SizedBox(height: 36),
                const Center(child: LdLanguageToggle()),
                const SizedBox(height: 28),
                LdButton(
                  label: l10n.welcomeStart,
                  onPressed: () => context.go(Routes.connect),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
