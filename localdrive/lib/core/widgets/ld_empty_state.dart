import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';
import 'ld_button.dart';
import 'ld_icons.dart';

/// Every list that can be empty renders this, never nothing and never a bare
/// "No items" text. One widget, parameterized per screen, with an illustration
/// from the same layered, two tone family as the file icons.
class LdEmptyState extends StatelessWidget {
  const LdEmptyState({
    super.key,
    required this.title,
    this.message,
    this.glyph = LdGlyph.folder,
    this.tint,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final LdGlyph glyph;
  final Color? tint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? LdColors.foregroundSecondary;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 24 : 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LayeredBadge(glyph: glyph, tint: accent, size: compact ? 64 : 88),
              SizedBox(height: compact ? 16 : 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 24),
                LdButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The two panel illustration shape shared by the empty and error states, so
/// they read as one family rather than two unrelated drawings.
class _LayeredBadge extends StatelessWidget {
  const _LayeredBadge({
    required this.glyph,
    required this.tint,
    required this.size,
  });

  final LdGlyph glyph;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // back panel, offset and darker
          Positioned(
            left: size * 0.08,
            top: size * 0.12,
            child: Container(
              width: size * 0.78,
              height: size * 0.66,
              decoration: BoxDecoration(
                color: LdColors.backPanel(tint).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(LdRadii.tile),
              ),
            ),
          ),
          // front panel
          Positioned(
            right: size * 0.06,
            bottom: size * 0.08,
            child: Container(
              width: size * 0.8,
              height: size * 0.68,
              decoration: BoxDecoration(
                color: LdColors.backgroundElevated,
                borderRadius: BorderRadius.circular(LdRadii.tile),
                border: Border.all(color: tint.withValues(alpha: 0.45)),
              ),
              child: Center(
                child: LdIcon(glyph, size: size * 0.32, color: tint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
