import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ld_colors.dart';

/// Typography is a function of the current locale, not a static class.
///
/// Space Grotesk was designed for Latin script and has no Arabic glyphs, so
/// one font for the whole app was never really an option once Arabic is a
/// first class language. IBM Plex Sans Arabic is the pairing: the same
/// engineered, geometric character, so the two read as a deliberate pair
/// rather than two unrelated fonts stitched together at the locale boundary.
///
/// Both load through google_fonts, which fetches on first use and caches on
/// device after that. The very first run in Arabic with no network yet renders
/// in the platform default for a moment before the real face swaps in. That is
/// expected, not a bug.
abstract final class LdTypography {
  /// swapping the Arabic face is this one line; Cairo and Tajawal are both
  /// reasonable alternatives if this pairing does not land on screen
  static TextTheme _arabicBase(TextTheme base) =>
      GoogleFonts.ibmPlexSansArabicTextTheme(base);

  static TextTheme _latinBase(TextTheme base) =>
      GoogleFonts.spaceGroteskTextTheme(base);

  /// Resolves the whole named scale for one language code.
  static TextTheme forLanguage(String languageCode) {
    final scale = _scale();
    final base = languageCode == 'ar' ? _arabicBase(scale) : _latinBase(scale);
    // google_fonts drops explicit sizes when merging, so the scale is applied
    // again on top of the resolved family
    return base.merge(scale);
  }

  /// Reads the locale off the context. Widgets never call this; they read
  /// `Theme.of(context).textTheme`, which is where this ends up.
  static TextTheme of(BuildContext context) =>
      forLanguage(Localizations.localeOf(context).languageCode);

  static TextTheme _scale() => const TextTheme(
        // display 32/38
        displayLarge: TextStyle(
          fontSize: 32,
          height: 38 / 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: LdColors.foregroundPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          height: 32 / 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: LdColors.foregroundPrimary,
        ),
        // title 20/26
        titleLarge: TextStyle(
          fontSize: 20,
          height: 26 / 20,
          fontWeight: FontWeight.w600,
          color: LdColors.foregroundPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          height: 24 / 17,
          fontWeight: FontWeight.w600,
          color: LdColors.foregroundPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          height: 22 / 15,
          fontWeight: FontWeight.w600,
          color: LdColors.foregroundPrimary,
        ),
        // body 15/22
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 22 / 15,
          fontWeight: FontWeight.w400,
          color: LdColors.foregroundPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          color: LdColors.foregroundSecondary,
        ),
        // caption 13/18
        bodySmall: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w400,
          color: LdColors.foregroundSecondary,
        ),
        // button 15
        labelLarge: TextStyle(
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: LdColors.foregroundPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: LdColors.foregroundSecondary,
        ),
        // 11px is the smallest text in the app, so it needs the most contrast,
        // not the least. This used foregroundMuted, which measures 1.86:1
        // against the base surface where 4.5:1 is the readable minimum, and it
        // is what a file's size and the storage figures are drawn in.
        // foregroundMuted stays for hairlines and disabled states, which are
        // shapes rather than something to read.
        labelSmall: TextStyle(
          fontSize: 11,
          height: 14 / 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: LdColors.foregroundSecondary,
        ),
      );

  /// The wordmark, one step heavier and tighter than display.
  static TextStyle wordmark(BuildContext context) =>
      Theme.of(context).textTheme.displayLarge!.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          );
}
