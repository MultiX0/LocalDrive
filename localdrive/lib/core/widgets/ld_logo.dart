import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';

/// The onboarding step the mark has reached. Each step brings one more layer
/// to life, so the logo builds itself up as a progress narrative rather than
/// sitting there as a static image.
enum LdLogoStage {
  /// welcome: a closed folder, at rest
  closed,

  /// connect to a server: the sheet rises out of the opening
  connected,

  /// language: the sync arc draws in
  syncing,

  /// sign in: the node fills solid, marking the mark complete
  complete,
}

/// The Local Drive mark.
///
/// Solid layered panels rather than a thin outline: a back panel carrying the
/// tab, a sheet peeking out of the opening, and a front panel over it. Still
/// flat and still fast, with no gradients and no shadows, but built from
/// enough shapes to have real visual weight at any size.
class LdLogo extends StatefulWidget {
  const LdLogo({
    super.key,
    this.size = 96,
    this.stage = LdLogoStage.complete,
    this.animate = true,
  });

  final double size;
  final LdLogoStage stage;
  final bool animate;

  @override
  State<LdLogo> createState() => _LdLogoState();
}

class _LdLogoState extends State<LdLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LdMotion.authStep,
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(LdLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage && widget.animate) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(
            stage: widget.stage,
            progress: Curves.easeOutCubic.transform(_controller.value),
          ),
        ),
      ),
    );
  }
}

/// The mark's palette. The back panel is a darker companion of the accent, the
/// sheet is a light neutral, and the front panel is the accent itself.
abstract final class LdMarkColors {
  static const Color back = Color(0xFF2A6FD6);
  static const Color sheet = Color(0xFFDCE3EE);
  static const Color front = LdColors.accentPrimary;
  static const Color mark = Color(0xFFFFFFFF);
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.stage, required this.progress});

  final LdLogoStage stage;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // authored on a 64 by 64 box, the same as mark.svg
    final unit = size.width / 64;
    canvas.save();
    canvas.scale(unit);

    final step = stage.index;

    // logo-back: the folder back and its tab
    canvas.drawPath(_backPanel(), Paint()..color = LdMarkColors.back);

    // logo-sheet: the contents, rising out of the opening once connected
    if (step >= LdLogoStage.connected.index) {
      final rising =
          step == LdLogoStage.connected.index ? progress : 1.0;
      canvas.save();
      // it slides up from behind the front panel, so it reads as arriving
      canvas.translate(0, 6 * (1 - rising));
      canvas.clipRect(const Rect.fromLTWH(0, 0, 64, 50));
      canvas.drawPath(
        _sheet(),
        Paint()..color = LdMarkColors.sheet.withValues(alpha: rising),
      );
      canvas.restore();
    }

    // logo-front: the brightest shape, over everything
    canvas.drawPath(_frontPanel(), Paint()..color = LdMarkColors.front);

    // logo-arc: the sync arc, drawn in a sweep at a time
    if (step >= LdLogoStage.syncing.index) {
      final drawn = step == LdLogoStage.syncing.index ? progress : 1.0;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(32, 38), radius: 8),
        // starts at the lower left and sweeps almost all the way round,
        // leaving the gap an arrow would enter through
        math.pi * 0.72,
        math.pi * 1.56 * drawn,
        false,
        Paint()
          ..color = LdMarkColors.mark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // logo-node: the connection dot at the centre of the arc
    if (step >= LdLogoStage.connected.index) {
      final filled =
          step == LdLogoStage.connected.index ? progress : 1.0;
      canvas.drawCircle(
        const Offset(32, 38),
        3.2 * filled,
        Paint()..color = LdMarkColors.mark,
      );
    }

    canvas.restore();
  }

  /// The folder back, with the raised tab on its left.
  static Path _backPanel() => Path()
    ..moveTo(10, 12)
    ..lineTo(24, 12)
    ..lineTo(29, 18)
    ..lineTo(54, 18)
    ..quadraticBezierTo(58, 18, 58, 22)
    ..lineTo(58, 46)
    ..quadraticBezierTo(58, 50, 54, 50)
    ..lineTo(10, 50)
    ..quadraticBezierTo(6, 50, 6, 46)
    ..lineTo(6, 16)
    ..quadraticBezierTo(6, 12, 10, 12)
    ..close();

  /// The sheet of contents peeking out of the opening.
  static Path _sheet() => Path()
    ..moveTo(14, 21)
    ..lineTo(50, 21)
    ..quadraticBezierTo(52, 21, 52, 23)
    ..lineTo(52, 44)
    ..lineTo(12, 44)
    ..lineTo(12, 23)
    ..quadraticBezierTo(12, 21, 14, 21)
    ..close();

  /// The front panel.
  static Path _frontPanel() => Path()
    ..moveTo(10, 26)
    ..lineTo(54, 26)
    ..quadraticBezierTo(58, 26, 58, 30)
    ..lineTo(58, 46)
    ..quadraticBezierTo(58, 50, 54, 50)
    ..lineTo(10, 50)
    ..quadraticBezierTo(6, 50, 6, 46)
    ..lineTo(6, 30)
    ..quadraticBezierTo(6, 26, 10, 26)
    ..close();

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.stage != stage || old.progress != progress;
}

/// The mark beside the wordmark, for the sidebar header and the About screen.
class LdWordmark extends StatelessWidget {
  const LdWordmark({super.key, required this.title, this.markSize = 30});

  final String title;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LdLogo(size: markSize, animate: false),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DefaultTextStyle.of(context).style,
          ),
        ),
      ],
    );
  }
}
