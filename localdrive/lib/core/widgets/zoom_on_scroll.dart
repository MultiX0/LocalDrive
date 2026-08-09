import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Turns the mouse wheel into zoom over a photo_view.
///
/// photo_view handles pinch, which is all a phone needs, and ignores the
/// wheel entirely. On a desktop or in a browser that leaves an image with no
/// way to zoom at all: there is nothing to pinch, and scrolling does nothing.
/// Every image viewer on those platforms zooms with the wheel, so this adds
/// the one gesture that was missing rather than replacing the ones that work.
class ZoomOnScroll extends StatelessWidget {
  const ZoomOnScroll({
    super.key,
    required this.controller,
    required this.child,
    this.minScale = 0.5,
    this.maxScale = 8,
  });

  final PhotoViewController controller;
  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (signal) {
        if (signal is! PointerScrollEvent) return;

        final current = controller.scale;
        if (current == null) return;

        // scale by a ratio rather than adding a fixed amount, so one notch
        // feels the same whether the image is already zoomed in or not
        final factor = signal.scrollDelta.dy > 0 ? 0.88 : 1 / 0.88;
        controller.scale = (current * factor).clamp(minScale, maxScale);
      },
      child: child,
    );
  }
}
