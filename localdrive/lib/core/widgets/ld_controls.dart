import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// A toggle, drawn rather than restyled, so it matches the rest of the kit
/// instead of carrying Material's shape and ripple.
class LdSwitch extends StatelessWidget {
  const LdSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = value && enabled;
    return Semantics(
      toggled: value,
      child: LdTappable(
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        enabled: enabled,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: LdMotion.tapFade,
          curve: LdMotion.curve,
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active
                ? LdColors.accentPrimary
                : LdColors.wash(LdColors.foregroundSecondary, 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? LdColors.accentPrimary : LdColors.strokeOutline,
            ),
          ),
          child: AnimatedAlign(
            duration: LdMotion.tapFade,
            curve: LdMotion.curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: enabled
                    ? LdColors.foregroundPrimary
                    : LdColors.foregroundMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A checkbox, for multi select. Also drawn rather than restyled.
class LdCheckbox extends StatelessWidget {
  const LdCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 22,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LdTappable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: LdMotion.tapFade,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? LdColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value ? LdColors.accentPrimary : LdColors.strokeOutline,
            width: 1.6,
          ),
        ),
        child: value
            ? Center(
                child: LdIcon(
                  LdGlyph.check,
                  size: size * 0.66,
                  color: LdColors.foregroundPrimary,
                  strokeWidth: 2.4,
                ),
              )
            : null,
      ),
    );
  }
}

/// A radio row, used wherever exactly one option applies.
class LdRadioRow extends StatelessWidget {
  const LdRadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LdTappable(
      onTap: onTap,
      borderRadius: LdRadii.tileRadius,
      child: Container(
        // symmetric, so a row sits the same distance from the card edge above
        // as below. a bottom-only margin left the first row flush against
        // the top of its card and the last one floating 8 off the bottom
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? LdColors.wash(LdColors.accentPrimary, 0.1)
              : LdColors.backgroundElevated,
          borderRadius: LdRadii.tileRadius,
          border: Border.all(
            color: selected ? LdColors.accentPrimary : LdColors.strokeOutline,
          ),
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: LdMotion.tapFade,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? LdColors.accentPrimary
                      : LdColors.strokeOutline,
                  width: 1.8,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: LdColors.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.bodyLarge),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A two or three way segmented control, used for the People and Link tabs in
/// the share sheet and for grid or list.
class LdSegmented<T> extends StatelessWidget {
  const LdSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.pillRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Row(
        children: <Widget>[
          for (final entry in segments.entries)
            Expanded(
              child: LdTappable(
                onTap: () => onChanged(entry.key),
                borderRadius: LdRadii.pillRadius,
                child: AnimatedContainer(
                  duration: LdMotion.tapFade,
                  curve: LdMotion.curve,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? LdColors.accentPrimary
                        : Colors.transparent,
                    borderRadius: LdRadii.pillRadius,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          color: entry.key == selected
                              ? LdColors.foregroundPrimary
                              : LdColors.foregroundSecondary,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A settings row: a label, an optional description, and a trailing control.
class LdSettingRow extends StatelessWidget {
  const LdSettingRow({
    super.key,
    required this.label,
    this.description,
    this.glyph,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String label;
  final String? description;
  final LdGlyph? glyph;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? LdColors.accentWarning
        : LdColors.foregroundPrimary;

    return LdTappable(
      onTap: onTap,
      borderRadius: LdRadii.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              LdIcon(glyph!, size: 19, color: color),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: color),
                  ),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              trailing!,
            ] else if (onTap != null)
              const LdIcon(
                LdGlyph.chevronRight,
                size: 18,
                color: LdColors.foregroundSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled group of settings rows.
class LdSettingGroup extends StatelessWidget {
  const LdSettingGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Container(
          // the 4 here plus a row's own 4 gives the same 8 between the card
          // edge and the first row as there is between any two rows
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: LdColors.backgroundElevated,
            borderRadius: LdRadii.cardRadius,
            border: Border.all(color: LdColors.strokeOutline),
          ),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(height: 1, color: LdColors.strokeOutline),
                children[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
