import '../../../../imports.dart';
import '../../widgets/onboarding_desktop_shell.dart';

/// Step one on desktop.
///
/// The phone centres one column because that is all it has. A window has the
/// rail, so the mark and the product name move there and this side carries
/// only the copy, the language choice, and the way forward. The three points
/// below are what a person setting up a server on a computer actually wants
/// answered before they start, and there is no room for them on a phone.
class WelcomePageDesktop extends StatelessWidget {
  const WelcomePageDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return OnboardingDesktopShell(
      step: OnboardingStep.welcome,
      title: l10n.welcomeTitle,
      subtitle: l10n.welcomeBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Point(glyph: LdGlyph.server, textKey: _PointKey.yourHardware),
          const _Point(glyph: LdGlyph.lock, textKey: _PointKey.yourKeys),
          const _Point(glyph: LdGlyph.device, textKey: _PointKey.everyDevice),
          const SizedBox(height: 36),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LdButton(
              label: l10n.welcomeStart,
              expand: false,
              onPressed: () => context.go(Routes.connect),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PointKey { yourHardware, yourKeys, everyDevice }

class _Point extends StatelessWidget {
  const _Point({required this.glyph, required this.textKey});

  final LdGlyph glyph;
  final _PointKey textKey;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final text = switch (textKey) {
      _PointKey.yourHardware => l10n.welcomePointHardware,
      _PointKey.yourKeys => l10n.welcomePointKeys,
      _PointKey.everyDevice => l10n.welcomePointDevices,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LdColors.backgroundElevated,
              borderRadius: LdRadii.chipRadius,
            ),
            child: LdIcon(glyph, size: 17, color: LdColors.accentPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: LdColors.foregroundSecondary,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
