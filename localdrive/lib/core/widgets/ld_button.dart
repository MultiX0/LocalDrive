import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';
import 'ld_hoverable.dart';
import 'ld_icons.dart';
import 'ld_spinner.dart';
import 'ld_tappable.dart';

/// Which of the four button roles this is.
enum LdButtonVariant { primary, secondary, destructive, text }

/// A fully custom button, not a restyled Material one, so there is no
/// ButtonStyle default to accidentally miss.
///
/// Its label is built from `Theme.of(context).textTheme.labelLarge` resolved at
/// build time, never a constant created once and reused. That single rule is
/// what actually prevents the button font from lagging a locale change.
class LdButton extends StatelessWidget {
  const LdButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = LdButtonVariant.primary,
    this.glyph,
    this.busy = false,
    this.expand = true,
    this.compact = false,
  });

  const LdButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.busy = false,
    this.expand = true,
    this.compact = false,
  }) : variant = LdButtonVariant.secondary;

  const LdButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.busy = false,
    this.expand = true,
    this.compact = false,
  }) : variant = LdButtonVariant.destructive;

  const LdButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.busy = false,
    this.expand = false,
    this.compact = true,
  }) : variant = LdButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final LdButtonVariant variant;
  final LdGlyph? glyph;
  final bool busy;
  final bool expand;
  final bool compact;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final scheme = _resolve();
    final height = compact ? 38.0 : LdRadii.buttonHeight;

    // resolved from the current theme at build time, never hardcoded
    final labelStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
          color: _enabled ? scheme.foreground : LdColors.foregroundMuted,
        );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy) ...<Widget>[
          LdSpinner(size: 18, color: scheme.foreground),
          const SizedBox(width: 10),
        ] else if (glyph != null) ...<Widget>[
          LdIcon(
            glyph!,
            size: 18,
            color: _enabled ? scheme.foreground : LdColors.foregroundMuted,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: LdHoverable(
        enabled: _enabled,
        builder: (context, hovered) => LdTappable(
          onTap: _enabled ? onPressed : null,
          enabled: _enabled,
          borderRadius: LdRadii.pillRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: height,
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
            decoration: BoxDecoration(
              color: !_enabled
                  ? scheme.disabledBackground
                  : hovered
                      ? LdHoverable.lift(scheme.background)
                      : scheme.background,
              borderRadius: LdRadii.pillRadius,
              border: scheme.border == null
                  ? null
                  : Border.all(
                      color: !_enabled
                          ? LdColors.strokeOutline
                          : hovered
                              ? LdColors.foregroundSecondary
                              : scheme.border!,
                    ),
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  _ButtonScheme _resolve() => switch (variant) {
        LdButtonVariant.primary => const _ButtonScheme(
            background: LdColors.accentPrimary,
            foreground: LdColors.foregroundPrimary,
            disabledBackground: LdColors.backgroundElevated,
          ),
        LdButtonVariant.secondary => const _ButtonScheme(
            background: Color(0x00000000),
            foreground: LdColors.foregroundPrimary,
            border: LdColors.strokeOutline,
            disabledBackground: Color(0x00000000),
          ),
        LdButtonVariant.destructive => const _ButtonScheme(
            background: Color(0x00000000),
            foreground: LdColors.accentWarning,
            border: LdColors.accentWarning,
            disabledBackground: Color(0x00000000),
          ),
        LdButtonVariant.text => const _ButtonScheme(
            background: Color(0x00000000),
            foreground: LdColors.accentPrimary,
            disabledBackground: Color(0x00000000),
          ),
      };
}

class _ButtonScheme {
  const _ButtonScheme({
    required this.background,
    required this.foreground,
    required this.disabledBackground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color disabledBackground;
  final Color? border;
}

/// The 42dp circular utility button from the reference screens.
class LdUtilityButton extends StatelessWidget {
  const LdUtilityButton({
    super.key,
    required this.glyph,
    this.onPressed,
    this.tooltip,
    this.active = false,
    this.badge = 0,
    this.color,
  });

  final LdGlyph glyph;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;

  /// a small count, for the pending devices badge on Settings
  final int badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ??
        (active ? LdColors.accentPrimary : LdColors.foregroundPrimary);

    Widget button = LdHoverable(
      enabled: onPressed != null,
      builder: (context, hovered) => LdTappable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(LdRadii.utilityButtonSize),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: LdRadii.utilityButtonSize,
          height: LdRadii.utilityButtonSize,
          decoration: BoxDecoration(
            color: LdHoverable.lift(
              active
                  ? LdColors.wash(LdColors.accentPrimary)
                  : LdColors.backgroundElevated,
              hovered ? 0.10 : 0,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? LdColors.accentPrimary
                  : hovered
                      ? LdColors.foregroundSecondary
                      : LdColors.strokeOutline,
            ),
          ),
          child: Center(child: LdIcon(glyph, size: 20, color: foreground)),
        ),
      ),
    );

    // The circle is 42, which looks right and is under the 48 both Material
    // and the Apple guidelines set as the smallest thing a finger should have
    // to hit. Growing the circle would make the toolbar heavy, so the target
    // grows instead and the drawing stays where it was.
    button = Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        width: LdRadii.minTouchTarget,
        height: LdRadii.minTouchTarget,
        child: Center(child: button),
      ),
    );

    if (badge > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          button,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: LdColors.accentPrimary,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: LdColors.backgroundPrimary, width: 2),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: LdColors.foregroundPrimary,
                      letterSpacing: 0,
                    ),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
