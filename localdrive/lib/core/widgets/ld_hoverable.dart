import 'package:flutter/material.dart';

// Tracks pointer hover and rebuilds with it.
//
// A pointer is a desktop and web idea, so this is where the difference between
// those and a touch screen lives. On a phone nothing ever enters, hovered stays
// false, and the builder runs once.
//
// The lift below is a flat colour change rather than a shadow, because nothing
// in this app casts one.
class LdHoverable extends StatefulWidget {
  const LdHoverable({
    super.key,
    required this.builder,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final bool enabled;
  final MouseCursor cursor;

  /// Lightens a surface by a fixed amount, for the hovered state.
  ///
  /// White at low opacity rather than a lighter hardcoded colour, so it works
  /// on every surface and on both accents without a second constant per case.
  static Color lift(Color base, [double amount = 0.10]) =>
      Color.alphaBlend(Colors.white.withValues(alpha: amount), base);

  @override
  State<LdHoverable> createState() => _LdHoverableState();
}

class _LdHoverableState extends State<LdHoverable> {
  bool _hovered = false;

  void _set(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  void didUpdateWidget(LdHoverable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // a control that becomes disabled under the pointer should not stay lit
    if (!widget.enabled && _hovered) _set(false);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? widget.cursor : SystemMouseCursors.basic,
      onEnter: (_) => widget.enabled ? _set(true) : null,
      onExit: (_) => _set(false),
      child: widget.builder(context, _hovered && widget.enabled),
    );
  }
}
