import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';
import 'ld_button.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// A discovered server or a device waiting for approval. Both are the same
/// pattern: here is something on the network, decide what to do with it.
class LdNodeListItem extends StatelessWidget {
  const LdNodeListItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.glyph = LdGlyph.server,
    this.status,
    this.statusColor,
    this.onTap,
    this.primaryAction,
    this.secondaryAction,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final LdGlyph glyph;

  /// a short ready or needs setup indicator
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;

  /// Approve, or Connect
  final Widget? primaryAction;

  /// Deny
  final Widget? secondaryAction;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LdTappable(
        onTap: onTap,
        borderRadius: LdRadii.tileRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LdColors.backgroundElevated,
            borderRadius: LdRadii.tileRadius,
            border: Border.all(
              color: selected ? LdColors.accentPrimary : LdColors.strokeOutline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: LdColors.wash(LdColors.accentPrimary, 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: LdIcon(
                        glyph,
                        size: 20,
                        color: LdColors.accentPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(width: 10),
                    _StatusPill(
                      label: status!,
                      color: statusColor ?? LdColors.fileSpreadsheet,
                    ),
                  ],
                  if (onTap != null &&
                      primaryAction == null &&
                      secondaryAction == null) ...<Widget>[
                    const SizedBox(width: 6),
                    const LdIcon(
                      LdGlyph.chevronRight,
                      size: 18,
                      color: LdColors.foregroundSecondary,
                    ),
                  ],
                ],
              ),
              if (primaryAction != null || secondaryAction != null) ...<Widget>[
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    if (secondaryAction != null)
                      Expanded(child: secondaryAction!),
                    if (secondaryAction != null && primaryAction != null)
                      const SizedBox(width: 10),
                    if (primaryAction != null) Expanded(child: primaryAction!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: LdColors.wash(color, 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall!
                .copyWith(color: color, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}

/// The Approve and Deny pair, so both the Devices screen and the onboarding
/// list build them the same way.
class LdApprovalActions extends StatelessWidget {
  const LdApprovalActions({
    super.key,
    required this.approveLabel,
    required this.denyLabel,
    required this.onApprove,
    required this.onDeny,
    this.busy = false,
  });

  final String approveLabel;
  final String denyLabel;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: LdButton.secondary(
            label: denyLabel,
            onPressed: busy ? null : onDeny,
            compact: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LdButton(
            label: approveLabel,
            onPressed: busy ? null : onApprove,
            busy: busy,
            compact: true,
          ),
        ),
      ],
    );
  }
}
