import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// One destination in the floating bar.
class LdNavItem {
  const LdNavItem({
    required this.glyph,
    required this.label,
    this.badge = 0,
    this.emphasized = false,
  });

  final LdGlyph glyph;
  final String label;
  final int badge;

  /// the create action, drawn as a filled accent circle in the middle
  final bool emphasized;
}

/// The floating pill bottom bar on mobile. Not Material's NavigationBar.
class LdBottomNav extends StatelessWidget {
  const LdBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<LdNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: LdColors.backgroundElevated,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: LdColors.strokeOutline),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LdNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (item.emphasized) {
      return Center(
        child: LdTappable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: LdColors.accentPrimary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: LdIcon(
                item.glyph,
                size: 22,
                color: LdColors.foregroundPrimary,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    final color =
        selected ? LdColors.accentPrimary : LdColors.foregroundSecondary;

    return LdTappable(
      onTap: onTap,
      borderRadius: LdRadii.pillRadius,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                LdIcon(item.glyph, size: 21, color: color),
                if (item.badge > 0)
                  Positioned(
                    top: -3,
                    right: -5,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: LdColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: LdMotion.tapFade,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: color,
                    letterSpacing: 0,
                  ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The persistent desktop sidebar. Same destinations, laid out for a pointer.
class LdSidebar extends StatelessWidget {
  const LdSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.header,
    this.footer,
  });

  final List<LdNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: LdColors.backgroundPrimary,
        border: Border(
          right: BorderSide(color: LdColors.strokeOutline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: header!,
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) => _SidebarRow(
                item: items[index],
                selected: index == currentIndex,
                onTap: () => onSelected(index),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final LdNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? LdColors.accentPrimary : LdColors.foregroundSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: LdTappable(
        onTap: onTap,
        borderRadius: LdRadii.tileRadius,
        child: AnimatedContainer(
          duration: LdMotion.tapFade,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? LdColors.wash(LdColors.accentPrimary, 0.12)
                : Colors.transparent,
            borderRadius: LdRadii.tileRadius,
          ),
          child: Row(
            children: <Widget>[
              LdIcon(item.glyph, size: 19, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: selected
                            ? LdColors.foregroundPrimary
                            : LdColors.foregroundSecondary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
              if (item.badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: LdColors.accentPrimary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    item.badge > 99 ? '99+' : '${item.badge}',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: LdColors.foregroundPrimary,
                          letterSpacing: 0,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
