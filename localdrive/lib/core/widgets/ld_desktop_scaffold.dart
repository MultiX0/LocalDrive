import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';
import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// The desktop page shell. Not the mobile scaffold with more padding: a
/// single slim top bar carries the title, the actions, and a search field
/// inline, all on one row, instead of a stacked header with a separate
/// toolbar underneath.
class LdDesktopScaffold extends StatelessWidget {
  const LdDesktopScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions = const <Widget>[],
    this.search,
    this.detail,
    this.detailWidth = Breakpoints.detailPaneWidth,
    this.banner,
    this.contentMaxWidth,
  });

  final Widget body;
  final String? title;

  /// a breadcrumb, usually, which is a title only a desktop has room for
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> actions;

  /// the inline search field, which lives in the top bar rather than on its
  /// own screen the way it does on a phone
  final Widget? search;

  /// the right hand pane, shown only when there is something to put in it
  final Widget? detail;
  final double detailWidth;
  final Widget? banner;

  /// forms and reading columns stay narrow even in a very wide window
  final double? contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (contentMaxWidth != null) {
      content = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth!),
          child: content,
        ),
      );
    }

    return Column(
      children: <Widget>[
        // No title bar here. The shell already puts one across the whole
        // window, and this one only spanned the content area, so the app drew
        // two: a full width bar with the real window buttons, and a second set
        // sitting inside the content next to the sidebar.
        _TopBar(
          title: title,
          titleWidget: titleWidget,
          subtitle: subtitle,
          actions: actions,
          search: search,
        ),
        ?banner,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: content),
              if (detail != null) ...<Widget>[
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: LdColors.strokeOutline,
                ),
                SizedBox(width: detailWidth, child: detail),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The one row of chrome at the top of every desktop screen.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.titleWidget,
    required this.subtitle,
    required this.actions,
    required this.search,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? search;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: LdColors.backgroundPrimary,
        border: Border(
          bottom: BorderSide(color: LdColors.strokeOutline),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: titleWidget ??
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null)
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
          ),
          if (search != null) ...<Widget>[
            const SizedBox(width: 24),
            // search is always reachable on desktop, never a separate screen
            Expanded(flex: 2, child: search!),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The right hand pane's own header, so a detail view reads as a panel rather
/// than as content that happened to land on the right.
class LdDetailPane extends StatelessWidget {
  const LdDetailPane({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LdColors.backgroundPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final action in actions) action,
                if (onClose != null)
                  LdTappable(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: LdIcon(
                        LdGlyph.close,
                        size: 18,
                        color: LdColors.foregroundSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The master and detail split settings uses on desktop: sections down the
/// left, the chosen one filling the rest, instead of a phone's push and pop.
class LdMasterDetail extends StatelessWidget {
  const LdMasterDetail({
    super.key,
    required this.sections,
    required this.selected,
    required this.onSelected,
    required this.child,
    this.masterWidth = 220,
  });

  final List<({String id, String label, LdGlyph glyph})> sections;
  final String selected;
  final ValueChanged<String> onSelected;
  final Widget child;
  final double masterWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: masterWidth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            children: <Widget>[
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: LdTappable(
                    onTap: () => onSelected(section.id),
                    borderRadius: LdRadii.tileRadius,
                    child: AnimatedContainer(
                      duration: LdMotion.tapFade,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: section.id == selected
                            ? LdColors.wash(LdColors.accentPrimary, 0.12)
                            : Colors.transparent,
                        borderRadius: LdRadii.tileRadius,
                      ),
                      child: Row(
                        children: <Widget>[
                          LdIcon(
                            section.glyph,
                            size: 18,
                            color: section.id == selected
                                ? LdColors.accentPrimary
                                : LdColors.foregroundSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              section.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    color: section.id == selected
                                        ? LdColors.foregroundPrimary
                                        : LdColors.foregroundSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const VerticalDivider(
          width: 1,
          thickness: 1,
          color: LdColors.strokeOutline,
        ),
        Expanded(child: child),
      ],
    );
  }
}
