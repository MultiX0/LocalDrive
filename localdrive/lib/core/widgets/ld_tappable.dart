import 'package:flutter/widgets.dart';

import '../constants/ld_motion.dart';

/// The one press affordance in the app: a short opacity fade, never a Material
/// ripple. Every interactive surface wraps in this instead of InkWell.
class LdTappable extends StatefulWidget {
  const LdTappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.borderRadius,
    this.pressedOpacity = 0.6,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
    this.onHoverChanged,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Right click on desktop, which is where the context menu opens.
  ///
  /// It carries the point that was clicked, because a desktop menu opens at
  /// the pointer. Without that the caller has nowhere to put the panel and
  /// has to fall back to a sheet, which is not what right click does on a
  /// desktop.
  final ValueChanged<Offset>? onSecondaryTap;
  final BorderRadius? borderRadius;
  final double pressedOpacity;
  final bool enabled;
  final MouseCursor cursor;
  final ValueChanged<bool>? onHoverChanged;
  final HitTestBehavior behavior;

  @override
  State<LdTappable> createState() => _LdTappableState();
}

class _LdTappableState extends State<LdTappable> {
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled &&
      (widget.onTap != null ||
          widget.onLongPress != null ||
          widget.onSecondaryTap != null);

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedOpacity(
      opacity: _pressed ? widget.pressedOpacity : 1,
      duration: LdMotion.tapFade,
      curve: LdMotion.curve,
      child: widget.child,
    );

    final gesture = GestureDetector(
      behavior: widget.behavior,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      onSecondaryTapUp: widget.enabled && widget.onSecondaryTap != null
          ? (details) => widget.onSecondaryTap!(details.globalPosition)
          : null,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: widget.borderRadius == null
          ? content
          : ClipRRect(borderRadius: widget.borderRadius!, child: content),
    );

    if (!_interactive) return gesture;

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => widget.onHoverChanged?.call(true),
      onExit: (_) => widget.onHoverChanged?.call(false),
      child: gesture,
    );
  }
}
