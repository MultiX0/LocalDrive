import 'package:flutter/material.dart';

import '../../../core/constants/ld_colors.dart';
import '../../../core/constants/ld_radii.dart';
import '../../../core/widgets/ld_icons.dart';
import '../../../core/widgets/ld_tappable.dart';

// One line in the about list: a label, a value or a link, and nothing else.
class AboutRow extends StatelessWidget {
  const AboutRow({
    super.key,
    required this.label,
    this.value,
    this.onTap,
    this.glyph,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final LdGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            LdIcon(glyph!, size: 18, color: LdColors.foregroundSecondary),
            const SizedBox(width: 12),
          ],
          // Label left, value hard right.
          //
          // Both halves are Expanded and the value is aligned to the end of
          // its own half, which is the row's right edge. A Spacer plus a
          // Flexible does not do this: the Spacer is tight and takes exactly
          // its share of the free space while the Flexible shrinks to its
          // text, so a short value like MIT gets parked in the middle of the
          // card looking deliberate and wrong.
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: LdColors.foregroundPrimary,
              ),
            ),
          ),
          if (value != null) ...<Widget>[
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value!,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: LdColors.foregroundSecondary,
                ),
              ),
            ),
          ],
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 8),
            const LdIcon(
              LdGlyph.chevronRight,
              size: 16,
              color: LdColors.foregroundMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return LdTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LdRadii.tile),
      child: row,
    );
  }
}

// The card the rows sit in. Flat fill and a single hairline border, which is
// what every other surface in the app does.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: LdColors.foregroundMuted,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: LdColors.backgroundElevated,
            borderRadius: BorderRadius.circular(LdRadii.card),
            border: Border.all(color: LdColors.strokeOutline),
          ),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    color: LdColors.strokeOutline,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
