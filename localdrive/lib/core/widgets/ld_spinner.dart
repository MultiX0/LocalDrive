import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';

/// The dot ring spinner, used everywhere instead of CircularProgressIndicator.
/// A ring of small circles with one highlighted, travelling around.
class LdSpinner extends StatefulWidget {
  const LdSpinner({
    super.key,
    this.size = 28,
    this.color,
    this.dotCount = 8,
  });

  final double size;
  final Color? color;
  final int dotCount;

  @override
  State<LdSpinner> createState() => _LdSpinnerState();
}

class _LdSpinnerState extends State<LdSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LdMotion.spinner,
  )..repeat();

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
          painter: _DotRingPainter(
            progress: _controller.value,
            color: widget.color ?? LdColors.accentPrimary,
            dotCount: widget.dotCount,
          ),
        ),
      ),
    );
  }
}

class _DotRingPainter extends CustomPainter {
  const _DotRingPainter({
    required this.progress,
    required this.color,
    required this.dotCount,
  });

  final double progress;
  final Color color;
  final int dotCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRadius = size.width / 2 - size.width * 0.12;
    final dotRadius = size.width * 0.09;
    final lead = (progress * dotCount).floor() % dotCount;

    for (var i = 0; i < dotCount; i++) {
      // the highlighted dot fades out behind the leader rather than blinking
      final distance = (lead - i + dotCount) % dotCount;
      final strength = 1 - (distance / dotCount);
      final angle = -math.pi / 2 + (i / dotCount) * 2 * math.pi;
      final offset = center +
          Offset(ringRadius * math.cos(angle), ringRadius * math.sin(angle));

      canvas.drawCircle(
        offset,
        dotRadius * (0.6 + 0.4 * strength),
        Paint()..color = color.withValues(alpha: 0.15 + 0.85 * strength),
      );
    }
  }

  @override
  bool shouldRepaint(_DotRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// A spinner centered in whatever space it is given, for a whole-page load.
class LdSpinnerPage extends StatelessWidget {
  const LdSpinnerPage({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const LdSpinner(size: 34),
          if (label != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              label!,
              style: DefaultTextStyle.of(context).style,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
