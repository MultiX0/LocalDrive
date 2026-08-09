import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';
import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import 'ld_button.dart';
import 'ld_icons.dart';
import 'ld_responsive.dart';
import 'ld_tappable.dart';

/// The single replacement for every dialog, menu, confirmation, form, and
/// picker in the app. There is no AlertDialog and no showDialog anywhere.
///
/// On desktop it centers as a panel rather than sliding from the bottom edge,
/// because a full width sheet on a wide screen reads as a mistake, but it is
/// the same component with the same branding either way.
class LdBottomSheet extends StatelessWidget {
  const LdBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showHandle = true,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool showHandle;
  final bool scrollable;

  /// Opens a branded sheet and returns whatever the caller pops with.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required WidgetBuilder builder,
    String? subtitle,
    List<Widget> Function(BuildContext context)? actions,
    bool dismissible = true,
    bool scrollable = true,
  }) {
    final deviceClass = LdDeviceScope.of(context);

    // a centred dialog on anything with a pointer, whatever the window width
    if (deviceClass.isDesktop || isPointerPlatform) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: dismissible,
        barrierLabel: title,
        barrierColor: const Color(0x99000000),
        transitionDuration: LdMotion.sheet,
        pageBuilder: (context, animation, secondary) => const SizedBox.shrink(),
        transitionBuilder: (context, animation, secondary, _) {
          final curved =
              CurvedAnimation(parent: animation, curve: LdMotion.curve);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                    maxHeight: 640,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: LdRadii.cardRadius,
                      child: LdBottomSheet(
                        title: title,
                        subtitle: subtitle,
                        showHandle: false,
                        scrollable: scrollable,
                        actions: actions?.call(context) ?? const <Widget>[],
                        child: Builder(builder: builder),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      constraints: const BoxConstraints(maxWidth: Breakpoints.tabletMax),
      builder: (context) => LdBottomSheet(
        title: title,
        subtitle: subtitle,
        scrollable: scrollable,
        actions: actions?.call(context) ?? const <Widget>[],
        child: Builder(builder: builder),
      ),
    );
  }

  /// A confirmation, with an optional typed phrase for the destructive ones.
  /// The phrase is the friction a genuinely irreversible action deserves.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
    String? requiredPhrase,
    String? phraseHint,
  }) async {
    final result = await show<bool>(
      context,
      title: title,
      scrollable: false,
      builder: (context) => _ConfirmBody(
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        requiredPhrase: requiredPhrase,
        phraseHint: phraseHint,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showHandle) ...<Widget>[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: LdColors.foregroundMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20, showHandle ? 16 : 22, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LdTappable(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: LdIcon(
                    LdGlyph.close,
                    size: 20,
                    color: LdColors.foregroundSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: scrollable
                ? SingleChildScrollView(child: child)
                : child,
          ),
        ),
        if (actions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: 20 + media.viewInsets.bottom),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.sheetRadius,
        border: Border(
          top: BorderSide(color: LdColors.strokeOutline),
        ),
      ),
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: SafeArea(top: false, child: content),
    );
  }
}

class _ConfirmBody extends StatefulWidget {
  const _ConfirmBody({
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.requiredPhrase,
    this.phraseHint,
  });

  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? requiredPhrase;
  final String? phraseHint;

  @override
  State<_ConfirmBody> createState() => _ConfirmBodyState();
}

class _ConfirmBodyState extends State<_ConfirmBody> {
  final TextEditingController _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _matches = widget.requiredPhrase == null;
    _controller.addListener(() {
      final next = _controller.text.trim() == widget.requiredPhrase;
      if (next != _matches) setState(() => _matches = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.message, style: Theme.of(context).textTheme.bodyLarge),
        if (widget.requiredPhrase != null) ...<Widget>[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: LdColors.wash(LdColors.accentWarning, 0.1),
              borderRadius: LdRadii.fieldRadius,
              border: Border.all(
                color: LdColors.wash(LdColors.accentWarning, 0.4),
              ),
            ),
            child: Text(
              widget.requiredPhrase!,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    color: LdColors.accentWarning,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          _PhraseField(controller: _controller, hint: widget.phraseHint ?? ''),
        ],
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: LdButton.secondary(
                label: widget.cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.destructive
                  ? LdButton.destructive(
                      label: widget.confirmLabel,
                      onPressed: _matches
                          ? () => Navigator.of(context).pop(true)
                          : null,
                    )
                  : LdButton(
                      label: widget.confirmLabel,
                      onPressed: _matches
                          ? () => Navigator.of(context).pop(true)
                          : null,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhraseField extends StatelessWidget {
  const _PhraseField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LdColors.backgroundPrimary,
        borderRadius: LdRadii.fieldRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        autofocus: true,
        style: Theme.of(context).textTheme.bodyLarge,
        cursorColor: LdColors.accentPrimary,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
