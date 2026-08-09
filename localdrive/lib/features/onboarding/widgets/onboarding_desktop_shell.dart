import '../../../imports.dart';

/// The steps of first run, in order, so the desktop rail can say where you are.
enum OnboardingStep { welcome, connect, language, account }

/// The desktop frame for onboarding.
///
/// A wide window has room for something a phone does not: a permanent rail
/// that shows the whole of first run at once and marks where you are in it.
/// That removes the phone's central problem, which is that each step looks
/// identical and gives no sense of how many are left. The right side is the
/// only part that changes between steps.
class OnboardingDesktopShell extends StatelessWidget {
  const OnboardingDesktopShell({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
  });

  final OnboardingStep step;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final labels = <OnboardingStep, String>{
      OnboardingStep.welcome: l10n.welcomeTitle,
      OnboardingStep.connect: l10n.connectTitle,
      OnboardingStep.language: l10n.languageTitle,
      OnboardingStep.account: l10n.signInTitle,
    };

    return Scaffold(
      backgroundColor: LdColors.backgroundPrimary,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // the rail: brand, then the full path through first run
            SizedBox(
              width: 340,
              child: Container(
                color: LdColors.backgroundSunken,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        LdLogo(size: 40, stage: _stageFor(step)),
                        const SizedBox(width: 12),
                        Text(
                          l10n.appName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    for (final entry in OnboardingStep.values)
                      _RailStep(
                        index: entry.index + 1,
                        label: labels[entry]!,
                        state: entry.index == step.index
                            ? _StepState.current
                            : entry.index < step.index
                                ? _StepState.done
                                : _StepState.upcoming,
                      ),
                    const Spacer(),
                    const LdLanguageToggle(compact: true),
                  ],
                ),
              ),
            ),
            // the step itself
            Expanded(
              child: Stack(
                children: <Widget>[
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 64,
                        vertical: 48,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              title,
                              style:
                                  Theme.of(context).textTheme.displayLarge,
                            ),
                            if (subtitle != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                subtitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                      color: LdColors.foregroundSecondary,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 36),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onBack != null)
                    Positioned(
                      top: 24,
                      left: 24,
                      child: LdButton.text(
                        label: l10n.actionBack,
                        glyph: LdGlyph.chevronLeft,
                        onPressed: onBack,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// the mark gains a layer per step, the same way it does on the phone
  static LdLogoStage _stageFor(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return LdLogoStage.closed;
      case OnboardingStep.connect:
        return LdLogoStage.connected;
      case OnboardingStep.language:
        return LdLogoStage.syncing;
      case OnboardingStep.account:
        return LdLogoStage.complete;
    }
  }
}

enum _StepState { done, current, upcoming }

class _RailStep extends StatelessWidget {
  const _RailStep({
    required this.index,
    required this.label,
    required this.state,
  });

  final int index;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final active = state != _StepState.upcoming;
    final color = switch (state) {
      _StepState.current => LdColors.accentPrimary,
      _StepState.done => LdColors.accentPrimary.withValues(alpha: 0.45),
      _StepState.upcoming => LdColors.strokeOutline,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: LdMotion.standard,
            curve: LdMotion.curve,
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: state == _StepState.current
                  ? LdColors.accentPrimary
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: state == _StepState.done
                ? const LdIcon(
                    LdGlyph.check,
                    size: 14,
                    color: LdColors.accentPrimary,
                  )
                : Text(
                    '$index',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: state == _StepState.current
                              ? LdColors.foregroundPrimary
                              : LdColors.foregroundMuted,
                        ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: active
                        ? LdColors.foregroundPrimary
                        : LdColors.foregroundMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
