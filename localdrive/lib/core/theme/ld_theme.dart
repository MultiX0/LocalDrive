import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import '../constants/ld_typography.dart';

/// Builds the one ThemeData the app uses, per locale.
///
/// The typography swap happens here, once, at the ThemeData level, so every
/// widget that reads `Theme.of(context).textTheme` gets the right face with no
/// exceptions to remember.
abstract final class LdTheme {
  static ThemeData forLocale(Locale locale) {
    final textTheme = LdTypography.forLanguage(locale.languageCode);

    final scheme = const ColorScheme.dark(
      primary: LdColors.accentPrimary,
      onPrimary: LdColors.foregroundPrimary,
      secondary: LdColors.accentPrimary,
      onSecondary: LdColors.foregroundPrimary,
      surface: LdColors.backgroundElevated,
      onSurface: LdColors.foregroundPrimary,
      error: LdColors.accentWarning,
      onError: LdColors.foregroundPrimary,
      outline: LdColors.strokeOutline,
    ).copyWith(surfaceContainerHighest: LdColors.backgroundElevated);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: LdColors.backgroundPrimary,
      canvasColor: LdColors.backgroundPrimary,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // no default material ripple anywhere; every interactive surface uses
      // the tap fade from LdMotion instead
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: LdColors.wash(LdColors.foregroundPrimary, 0.04),
      focusColor: LdColors.wash(LdColors.accentPrimary, 0.18),

      dividerTheme: const DividerThemeData(
        color: LdColors.strokeOutline,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: LdColors.foregroundPrimary,
        size: 22,
      ),

      // structural widgets are themed rather than left stock, so nothing
      // unstyled ever reaches the screen
      appBarTheme: AppBarTheme(
        backgroundColor: LdColors.backgroundPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: LdColors.foregroundPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: LdColors.backgroundPrimary,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LdColors.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: LdColors.backgroundElevated,
        modalBarrierColor: Color(0x99000000),
        shape: RoundedRectangleBorder(borderRadius: LdRadii.sheetRadius),
        elevation: 0,
        showDragHandle: false,
      ),

      cardTheme: const CardThemeData(
        color: LdColors.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: LdRadii.cardRadius),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: LdColors.backgroundElevated,
          borderRadius: LdRadii.chipRadius,
          border: Border.all(color: LdColors.strokeOutline),
        ),
        textStyle: textTheme.bodySmall,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 500),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          LdColors.wash(LdColors.foregroundSecondary, 0.35),
        ),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(4),
        crossAxisMargin: 2,
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: LdColors.accentPrimary,
        selectionColor: LdColors.wash(LdColors.accentPrimary, 0.3),
        selectionHandleColor: LdColors.accentPrimary,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _LdPageTransitions(),
          TargetPlatform.iOS: _LdPageTransitions(),
          TargetPlatform.macOS: _LdPageTransitions(),
          TargetPlatform.windows: _LdPageTransitions(),
          TargetPlatform.linux: _LdPageTransitions(),
        },
      ),

      extensions: const <ThemeExtension<dynamic>>[LdSurfaces()],
    );
  }
}

/// The standard transition, applied to every route push.
class _LdPageTransitions extends PageTransitionsBuilder {
  const _LdPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return LdMotion.fadeSlide(animation, child);
  }
}

/// Surface decorations reused across the widget kit, exposed as a theme
/// extension so nothing rebuilds a border by hand.
class LdSurfaces extends ThemeExtension<LdSurfaces> {
  const LdSurfaces();

  BoxDecoration get card => BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.cardRadius,
        border: Border.all(color: LdColors.strokeOutline),
      );

  BoxDecoration get tile => BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.tileRadius,
        border: Border.all(color: LdColors.strokeOutline),
      );

  BoxDecoration get field => BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.fieldRadius,
        border: Border.all(color: LdColors.strokeOutline),
      );

  BoxDecoration get pill => BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.pillRadius,
        border: Border.all(color: LdColors.strokeOutline),
      );

  @override
  LdSurfaces copyWith() => const LdSurfaces();

  @override
  LdSurfaces lerp(ThemeExtension<LdSurfaces>? other, double t) => this;
}

/// Shorthand every widget uses instead of rebuilding a decoration.
extension LdThemeContext on BuildContext {
  LdSurfaces get surfaces =>
      Theme.of(this).extension<LdSurfaces>() ?? const LdSurfaces();
}
