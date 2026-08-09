import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// A preset swatch row, not an open color wheel, so a folder can stand out
/// without the browser turning into a rainbow.
class LdColorPicker extends StatelessWidget {
  const LdColorPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = LdColors.folderSwatches.entries.toList(growable: false);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final entry in entries)
          _Swatch(
            color: entry.value,
            selected: (selected ?? 'neutral') == entry.key,
            onTap: () => onSelected(entry.key),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LdTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? LdColors.foregroundPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Center(
                child: LdIcon(
                  LdGlyph.check,
                  size: 20,
                  color: LdColors.backgroundPrimary,
                  strokeWidth: 2.4,
                ),
              )
            : null,
      ),
    );
  }
}
