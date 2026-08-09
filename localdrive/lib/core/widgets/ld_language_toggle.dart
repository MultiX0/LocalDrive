import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import '../services/core_providers.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// The language switch, small enough to sit in a corner.
///
/// It is reachable from the very first screen rather than only from a step
/// partway through onboarding, because someone who does not read the welcome
/// copy cannot be expected to navigate three screens in a language they do not
/// speak to reach the place where they could change it.
class LdLanguageToggle extends ConsumerWidget {
  const LdLanguageToggle({super.key, this.compact = false});

  /// the corner form: a globe and the language code, no full names
  final bool compact;

  static const List<({String code, String label})> languages =
      <({String code, String label})>[
    (code: 'en', label: 'English'),
    (code: 'ar', label: 'العربية'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider)?.languageCode ??
        Localizations.localeOf(context).languageCode;

    if (compact) {
      return LdTappable(
        onTap: () => _cycle(ref, current),
        borderRadius: LdRadii.pillRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: LdColors.backgroundElevated,
            borderRadius: LdRadii.pillRadius,
            border: Border.all(color: LdColors.strokeOutline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const LdIcon(
                LdGlyph.language,
                size: 16,
                color: LdColors.foregroundSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _labelFor(current),
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: LdColors.foregroundPrimary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // the full form: both languages side by side, each written in itself, so
    // neither is only readable to someone who already speaks the other
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.pillRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final language in languages)
            LdTappable(
              onTap: () => ref
                  .read(localeProvider.notifier)
                  .set(Locale(language.code)),
              borderRadius: LdRadii.pillRadius,
              child: AnimatedContainer(
                duration: LdMotion.tapFade,
                curve: LdMotion.curve,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: language.code == current
                      ? LdColors.accentPrimary
                      : Colors.transparent,
                  borderRadius: LdRadii.pillRadius,
                ),
                child: Text(
                  language.label,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: language.code == current
                            ? LdColors.foregroundPrimary
                            : LdColors.foregroundSecondary,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _cycle(WidgetRef ref, String current) {
    final index = languages.indexWhere((l) => l.code == current);
    final next = languages[(index + 1) % languages.length];
    ref.read(localeProvider.notifier).set(Locale(next.code));
  }

  static String _labelFor(String code) {
    for (final language in languages) {
      if (language.code == code) return language.label;
    }
    return languages.first.label;
  }
}
