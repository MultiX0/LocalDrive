import 'package:flutter/material.dart';

import 'ld_icons.dart';
import 'ld_responsive.dart';
import 'ld_tappable.dart';

/// The large title at the top of a phone screen, and the back control that
/// belongs beside it.
///
/// Shared, because four screens had hand rolled the same Row with the same
/// padding and drifted apart: one of them left eight pixels under the title,
/// which put the first card almost against it. A title needs air under it or
/// the screen reads as one block with a bigger word at the top.
class LdPageHeader extends StatelessWidget {
  const LdPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
  });

  final String title;

  /// shown when there is somewhere to go back to. A screen that hides the tab
  /// bar must pass this, or there is no way out of it
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        6,
        context.pagePadding,
        // the gap that separates the title from whatever the screen is about
        18,
      ),
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            LdTappable(
              onTap: onBack,
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                // 48 across once the glyph and padding are added up, which is
                // the smallest a thumb should ever be asked to hit
                padding: EdgeInsets.all(6),
                child: LdIcon(LdGlyph.chevronLeft, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
