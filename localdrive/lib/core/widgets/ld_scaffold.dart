import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// The one page shell. Scaffold is used structurally, but every visible part
/// of it is the app's own, so nothing unstyled reaches the screen.
class LdScaffold extends StatelessWidget {
  const LdScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onBack,
    this.showBack = false,
    this.bottomBar,
    this.floatingAction,
    this.padded = true,
    this.banner,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? bottomBar;
  final Widget? floatingAction;
  final bool padded;

  /// a persistent strip above the content, such as the offline notice
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        title != null || titleWidget != null || showBack || actions.isNotEmpty;

    return Scaffold(
      backgroundColor: LdColors.backgroundPrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            if (hasHeader)
              _Header(
                title: title,
                titleWidget: titleWidget,
                subtitle: subtitle,
                actions: actions,
                showBack: showBack,
                onBack: onBack,
                padded: padded,
              ),
            ?banner,
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingAction,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.titleWidget,
    required this.subtitle,
    required this.actions,
    required this.showBack,
    required this.onBack,
    required this.padded,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padded ? 16 : 8, 8, padded ? 16 : 8, 8),
      child: Row(
        children: <Widget>[
          if (showBack) ...<Widget>[
            LdTappable(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: LdIcon(LdGlyph.chevronLeft, size: 22),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: titleWidget ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (title != null)
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
          ),
          for (final action in actions) ...<Widget>[
            const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }
}

/// A persistent banner, used for a library that is offline or a queue that is
/// paused waiting for a connection.
class LdBanner extends StatelessWidget {
  const LdBanner({
    super.key,
    required this.message,
    this.glyph = LdGlyph.warning,
    this.tint,
    this.action,
  });

  final String message;
  final LdGlyph glyph;
  final Color? tint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? LdColors.filePresentation;
    return Container(
      width: double.infinity,
      color: LdColors.wash(accent, 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          LdIcon(glyph, size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: LdColors.foregroundPrimary),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
