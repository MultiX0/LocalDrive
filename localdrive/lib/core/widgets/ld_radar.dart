import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../constants/ld_colors.dart';

/// The network scan, drawn as a radar rather than a plain spinner, since
/// that is closer to what is actually happening: each server that turns up
/// gets somewhere to appear instead of popping into a list from nowhere.
class LdRadar extends StatefulWidget {
  const LdRadar({
    super.key,
    this.size = 220,
    this.blips = const <LdRadarBlip>[],
    this.scanning = true,
  });

  final double size;

  /// one per server found, placed around the ring
  final List<LdRadarBlip> blips;
  final bool scanning;

  @override
  State<LdRadar> createState() => _LdRadarState();
}

/// A server that turned up on the scan.
class LdRadarBlip {
  const LdRadarBlip({required this.seed, this.ready = false});

  /// hashed to a stable angle and distance, so a server does not jump around
  /// the dial between frames
  final String seed;
  final bool ready;
}

class _LdRadarState extends State<LdRadar> with TickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.scanning) {
      _sweep.repeat();
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(LdRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scanning && !_sweep.isAnimating) {
      _sweep.repeat();
      _pulse.repeat();
    } else if (!widget.scanning && _sweep.isAnimating) {
      _sweep.stop();
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_sweep, _pulse]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RadarPainter(
            sweep: _sweep.value,
            pulse: _pulse.value,
            blips: widget.blips,
            scanning: widget.scanning,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.sweep,
    required this.pulse,
    required this.blips,
    required this.scanning,
  });

  final double sweep;
  final double pulse;
  final List<LdRadarBlip> blips;
  final bool scanning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // three static rings, faint, so the dial reads as a dial
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        radius * (i / 3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = LdColors.wash(LdColors.foregroundSecondary, 0.14),
      );
    }

    // two crosshairs, fainter still
    final hair = Paint()
      ..strokeWidth = 1
      ..color = LdColors.wash(LdColors.foregroundSecondary, 0.09);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      hair,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      hair,
    );

    if (scanning) {
      // an expanding ping, so the dial has a pulse even before anything is found
      final pingRadius = radius * pulse;
      canvas.drawCircle(
        center,
        pingRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = LdColors.accentPrimary.withValues(alpha: 0.28 * (1 - pulse)),
      );

      // the sweep itself: a soft wedge trailing the leading edge
      final angle = sweep * 2 * math.pi - math.pi / 2;
      final wedge = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          angle - 0.85,
          0.85,
          false,
        )
        ..close();
      canvas.drawPath(
        wedge,
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: angle - 0.85,
            endAngle: angle,
            colors: <Color>[
              LdColors.accentPrimary.withValues(alpha: 0),
              LdColors.accentPrimary.withValues(alpha: 0.22),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

      // the leading edge, bright
      canvas.drawLine(
        center,
        center + Offset(radius * math.cos(angle), radius * math.sin(angle)),
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = LdColors.accentPrimary.withValues(alpha: 0.8),
      );
    }

    // whatever has been found, at a stable place on the dial
    for (final blip in blips) {
      final hash = _hash(blip.seed);
      final angle = (hash % 360) * math.pi / 180;
      final distance = radius * (0.42 + (hash >> 9) % 45 / 100);
      final at = center +
          Offset(distance * math.cos(angle), distance * math.sin(angle));

      final color =
          blip.ready ? LdColors.fileSpreadsheet : LdColors.filePresentation;

      // a halo that breathes, so a found server keeps drawing the eye
      canvas.drawCircle(
        at,
        7 + 4 * math.sin(pulse * 2 * math.pi),
        Paint()..color = color.withValues(alpha: 0.16),
      );
      canvas.drawCircle(at, 4.5, Paint()..color = color);
    }

    // the device itself, at the centre
    canvas.drawCircle(
      center,
      5,
      Paint()..color = LdColors.foregroundPrimary,
    );
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = LdColors.wash(LdColors.foregroundPrimary, 0.3),
    );
  }

  static int _hash(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.sweep != sweep ||
      old.pulse != pulse ||
      old.scanning != scanning ||
      old.blips.length != blips.length;
}
