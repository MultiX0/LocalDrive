import 'package:flutter/widgets.dart';

/// Every duration and curve in the app. One standard transition, used
/// everywhere, so nothing animates at an unfamiliar speed.
abstract final class LdMotion {
  /// fade plus a 16px upward slide, the app's one page transition
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration tapFade = Duration(milliseconds: 120);
  static const Duration authStep = Duration(milliseconds: 400);
  static const Duration sheet = Duration(milliseconds: 320);
  static const Duration toast = Duration(milliseconds: 240);
  static const Duration toastVisible = Duration(seconds: 4);
  static const Duration hover = Duration(milliseconds: 200);
  static const Duration spinner = Duration(milliseconds: 1200);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;

  /// how far the standard transition slides up from
  static const double slideOffset = 16;

  /// the shared enter animation, applied by the router and reused by any
  /// widget that wants the same feel
  static Widget fadeSlide(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: curve);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, inner) => Transform.translate(
          offset: Offset(0, slideOffset * (1 - curved.value)),
          child: inner,
        ),
        child: child,
      ),
    );
  }
}
