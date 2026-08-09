import 'package:flutter/widgets.dart';

import '../constants/ld_colors.dart';

/// The app's single line icon set, drawn rather than pulled from Material, so
/// nothing brand visible falls back to a stock glyph. Every path is authored
/// on a 24 by 24 box and stroked at a consistent weight.
enum LdGlyph {
  home,
  search,
  plus,
  shared,
  settings,
  folder,
  file,
  upload,
  download,
  star,
  starFilled,
  trash,
  restore,
  clock,
  grid,
  list,
  more,
  chevronRight,
  chevronLeft,
  chevronDown,
  close,
  check,
  link,
  people,
  person,
  device,
  drive,
  eject,
  refresh,
  wifi,
  lock,
  eye,
  eyeOff,
  edit,
  move,
  copy,
  info,
  warning,
  offline,
  offlineReady,
  play,
  pause,
  volume,
  volumeOff,
  fullscreen,
  fullscreenExit,
  image,
  music,
  code,
  archive,
  activity,
  logout,
  qr,
  sort,
  filter,
  arrowUp,
  arrowDown,
  server,
  language,
}

/// One icon. Size and color come from the caller, never from a global.
class LdIcon extends StatelessWidget {
  const LdIcon(
    this.glyph, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.7,
    this.mirrorInRtl = true,
  });

  final LdGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  /// directional glyphs mirror in Arabic; symmetric ones never should
  final bool mirrorInRtl;

  static const Set<LdGlyph> _directional = <LdGlyph>{
    LdGlyph.chevronRight,
    LdGlyph.chevronLeft,
    LdGlyph.logout,
    LdGlyph.restore,
    LdGlyph.move,
    LdGlyph.play,
  };

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? LdColors.foregroundPrimary;
    final flip = mirrorInRtl &&
        _directional.contains(glyph) &&
        Directionality.of(context) == TextDirection.rtl;

    final painted = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LdGlyphPainter(
          glyph: glyph,
          color: resolved,
          strokeWidth: strokeWidth,
        ),
      ),
    );
    if (!flip) return painted;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      child: painted,
    );
  }
}

class _LdGlyphPainter extends CustomPainter {
  const _LdGlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final LdGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case LdGlyph.home:
        canvas.drawPath(
          Path()
            ..moveTo(4, 10)
            ..lineTo(12, 3.5)
            ..lineTo(20, 10)
            ..lineTo(20, 19)
            ..lineTo(4, 19)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 19)
            ..lineTo(9.5, 13.5)
            ..lineTo(14.5, 13.5)
            ..lineTo(14.5, 19),
          stroke,
        );

      case LdGlyph.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6, stroke);
        canvas.drawLine(const Offset(15, 15), const Offset(20, 20), stroke);

      case LdGlyph.plus:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), stroke);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), stroke);

      case LdGlyph.shared:
        canvas.drawCircle(const Offset(6.5, 12), 2.6, stroke);
        canvas.drawCircle(const Offset(17, 6.5), 2.6, stroke);
        canvas.drawCircle(const Offset(17, 17.5), 2.6, stroke);
        canvas.drawLine(const Offset(8.9, 10.8), const Offset(14.7, 7.7), stroke);
        canvas.drawLine(const Offset(8.9, 13.2), const Offset(14.7, 16.3), stroke);

      case LdGlyph.settings:
        canvas.drawCircle(const Offset(12, 12), 3, stroke);
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawLine(const Offset(12, 4), const Offset(12, 6.5), stroke);
        canvas.drawLine(const Offset(12, 17.5), const Offset(12, 20), stroke);
        canvas.drawLine(const Offset(4, 12), const Offset(6.5, 12), stroke);
        canvas.drawLine(const Offset(17.5, 12), const Offset(20, 12), stroke);

      case LdGlyph.folder:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 8)
            ..lineTo(3.5, 6.5)
            ..quadraticBezierTo(3.5, 5.5, 4.5, 5.5)
            ..lineTo(9.5, 5.5)
            ..lineTo(11.5, 8)
            ..lineTo(19.5, 8)
            ..quadraticBezierTo(20.5, 8, 20.5, 9)
            ..lineTo(20.5, 17.5)
            ..quadraticBezierTo(20.5, 18.5, 19.5, 18.5)
            ..lineTo(4.5, 18.5)
            ..quadraticBezierTo(3.5, 18.5, 3.5, 17.5)
            ..close(),
          stroke,
        );

      case LdGlyph.file:
        canvas.drawPath(
          Path()
            ..moveTo(6, 3.5)
            ..lineTo(14, 3.5)
            ..lineTo(19, 8.5)
            ..lineTo(19, 20.5)
            ..lineTo(6, 20.5)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(14, 3.5)
            ..lineTo(14, 8.5)
            ..lineTo(19, 8.5),
          stroke,
        );

      case LdGlyph.upload:
        canvas.drawLine(const Offset(12, 16), const Offset(12, 4), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 8.5)
            ..lineTo(12, 4)
            ..lineTo(16.5, 8.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 15)
            ..lineTo(4.5, 19.5)
            ..lineTo(19.5, 19.5)
            ..lineTo(19.5, 15),
          stroke,
        );

      case LdGlyph.download:
        canvas.drawLine(const Offset(12, 4), const Offset(12, 16), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 11.5)
            ..lineTo(12, 16)
            ..lineTo(16.5, 11.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 15)
            ..lineTo(4.5, 19.5)
            ..lineTo(19.5, 19.5)
            ..lineTo(19.5, 15),
          stroke,
        );

      case LdGlyph.star:
      case LdGlyph.starFilled:
        final star = _starPath();
        canvas.drawPath(star, glyph == LdGlyph.starFilled ? fill : stroke);

      case LdGlyph.trash:
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 7)
            ..lineTo(18.5, 7)
            ..lineTo(17.4, 20)
            ..lineTo(6.6, 20)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(4, 7), const Offset(20, 7), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 7)
            ..lineTo(9.5, 4.5)
            ..lineTo(14.5, 4.5)
            ..lineTo(14.5, 7),
          stroke,
        );
        canvas.drawLine(const Offset(10.5, 11), const Offset(10.5, 16.5), stroke);
        canvas.drawLine(const Offset(13.5, 11), const Offset(13.5, 16.5), stroke);

      case LdGlyph.restore:
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 12), radius: 7.5),
            2.2, 4.6, false, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(4.6, 8.4)
            ..lineTo(4.2, 13)
            ..lineTo(8.8, 12.3),
          stroke,
        );

      case LdGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 7.5)
            ..lineTo(12, 12.3)
            ..lineTo(15.5, 14.2),
          stroke,
        );

      case LdGlyph.grid:
        for (final origin in const <Offset>[
          Offset(4.5, 4.5),
          Offset(13.5, 4.5),
          Offset(4.5, 13.5),
          Offset(13.5, 13.5),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(origin.dx, origin.dy, 6, 6),
              const Radius.circular(1.6),
            ),
            stroke,
          );
        }

      case LdGlyph.list:
        for (final y in const <double>[6.5, 12, 17.5]) {
          canvas.drawCircle(Offset(5, y), 1.1, fill);
          canvas.drawLine(Offset(9, y), Offset(19.5, y), stroke);
        }

      case LdGlyph.more:
        for (final x in const <double>[6, 12, 18]) {
          canvas.drawCircle(Offset(x, 12), 1.5, fill);
        }

      case LdGlyph.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 5.5)
            ..lineTo(16, 12)
            ..lineTo(9.5, 18.5),
          stroke,
        );

      case LdGlyph.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 5.5)
            ..lineTo(8, 12)
            ..lineTo(14.5, 18.5),
          stroke,
        );

      case LdGlyph.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 9.5)
            ..lineTo(12, 16)
            ..lineTo(18.5, 9.5),
          stroke,
        );

      case LdGlyph.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);

      case LdGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(10, 17.5)
            ..lineTo(19, 6.5),
          stroke,
        );

      case LdGlyph.link:
        canvas.drawPath(
          Path()
            ..moveTo(10, 14)
            ..lineTo(14, 10),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9, 15.5)
            ..lineTo(7, 17.5)
            ..quadraticBezierTo(4.5, 20, 6.5, 22)
            ..quadraticBezierTo(8.5, 24, 11, 21.5)
            ..lineTo(13, 19.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15, 8.5)
            ..lineTo(17, 6.5)
            ..quadraticBezierTo(19.5, 4, 17.5, 2)
            ..quadraticBezierTo(15.5, 0, 13, 2.5)
            ..lineTo(11, 4.5),
          stroke,
        );

      case LdGlyph.people:
        canvas.drawCircle(const Offset(9, 8.5), 3.2, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 19)
            ..quadraticBezierTo(3.5, 14, 9, 14)
            ..quadraticBezierTo(14.5, 14, 14.5, 19),
          stroke,
        );
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(16.5, 8.5), radius: 3.2),
            -1.2, 2.4, false, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(16.5, 14)
            ..quadraticBezierTo(21, 14.4, 21, 19),
          stroke,
        );

      case LdGlyph.person:
        canvas.drawCircle(const Offset(12, 8.5), 3.6, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(5, 19.5)
            ..quadraticBezierTo(5, 14, 12, 14)
            ..quadraticBezierTo(19, 14, 19, 19.5),
          stroke,
        );

      case LdGlyph.device:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 3, 10, 18),
            const Radius.circular(2.4),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(10.5, 18), const Offset(13.5, 18), stroke);

      case LdGlyph.drive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 6.5, 18, 11),
            const Radius.circular(2.6),
          ),
          stroke,
        );
        canvas.drawCircle(const Offset(17, 12), 1.4, fill);
        canvas.drawLine(const Offset(6.5, 12), const Offset(12.5, 12), stroke);

      case LdGlyph.eject:
        canvas.drawPath(
          Path()
            ..moveTo(6, 12.5)
            ..lineTo(12, 5)
            ..lineTo(18, 12.5)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(6, 17.5), const Offset(18, 17.5), stroke);

      case LdGlyph.refresh:
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 12), radius: 7.5),
            -1.0, 4.8, false, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(15.5, 2.8)
            ..lineTo(16.5, 6.8)
            ..lineTo(12.5, 7.2),
          stroke,
        );

      case LdGlyph.wifi:
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 18), radius: 4.5 + i * 4.0),
            3.6, 1.9, false, stroke,
          );
        }
        canvas.drawCircle(const Offset(12, 18), 1.4, fill);

      case LdGlyph.lock:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 10.5, 14, 9.5),
            const Radius.circular(2.4),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 10.5)
            ..lineTo(8, 8)
            ..quadraticBezierTo(8, 4, 12, 4)
            ..quadraticBezierTo(16, 4, 16, 8)
            ..lineTo(16, 10.5),
          stroke,
        );

      case LdGlyph.eye:
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 12)
            ..quadraticBezierTo(7, 5.5, 12, 5.5)
            ..quadraticBezierTo(17, 5.5, 21.5, 12)
            ..quadraticBezierTo(17, 18.5, 12, 18.5)
            ..quadraticBezierTo(7, 18.5, 2.5, 12)
            ..close(),
          stroke,
        );
        canvas.drawCircle(const Offset(12, 12), 3, stroke);

      case LdGlyph.eyeOff:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 12)
            ..quadraticBezierTo(7.5, 6, 12, 6)
            ..quadraticBezierTo(16.5, 6, 20.5, 12),
          stroke,
        );
        canvas.drawCircle(const Offset(12, 12.5), 2.8, stroke);
        canvas.drawLine(const Offset(4.5, 4.5), const Offset(19.5, 19.5), stroke);

      case LdGlyph.edit:
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 19.5)
            ..lineTo(5.4, 15.5)
            ..lineTo(16, 5)
            ..lineTo(19, 8)
            ..lineTo(8.5, 18.6)
            ..close(),
          stroke,
        );

      case LdGlyph.move:
        canvas.drawPath(
          Path()
            ..moveTo(4, 12)
            ..lineTo(15, 12),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(11.5, 8)
            ..lineTo(15.5, 12)
            ..lineTo(11.5, 16),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(18.5, 5)
            ..lineTo(18.5, 19),
          stroke,
        );

      case LdGlyph.copy:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 8, 12, 12),
            const Radius.circular(2.4),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 5.5)
            ..lineTo(6.5, 5.5)
            ..quadraticBezierTo(4.5, 5.5, 4.5, 7.5)
            ..lineTo(4.5, 16.5),
          stroke,
        );

      case LdGlyph.info:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawCircle(const Offset(12, 8), 1.1, fill);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 16.5), stroke);

      case LdGlyph.warning:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.5)
            ..lineTo(21, 19.5)
            ..lineTo(3, 19.5)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(12, 9), const Offset(12, 14), stroke);
        canvas.drawCircle(const Offset(12, 16.8), 1.1, fill);

      case LdGlyph.offline:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawLine(const Offset(6.5, 6.5), const Offset(17.5, 17.5), stroke);

      case LdGlyph.offlineReady:
        canvas.drawCircle(const Offset(12, 12), 8, fill);
        final tick = Paint()
          ..color = LdColors.backgroundPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 0.3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          Path()
            ..moveTo(8, 12.2)
            ..lineTo(11, 15.2)
            ..lineTo(16, 9),
          tick,
        );

      case LdGlyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 5.5)
            ..lineTo(18.5, 12)
            ..lineTo(8.5, 18.5)
            ..close(),
          stroke,
        );

      case LdGlyph.pause:
        canvas
          ..drawLine(const Offset(9, 5.5), const Offset(9, 18.5), stroke)
          ..drawLine(const Offset(15, 5.5), const Offset(15, 18.5), stroke);

      // the four corner brackets every player uses for full screen
      case LdGlyph.fullscreen:
        canvas
          ..drawPath(
            Path()
              ..moveTo(4, 9)
              ..lineTo(4, 4)
              ..lineTo(9, 4),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(15, 4)
              ..lineTo(20, 4)
              ..lineTo(20, 9),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(20, 15)
              ..lineTo(20, 20)
              ..lineTo(15, 20),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(9, 20)
              ..lineTo(4, 20)
              ..lineTo(4, 15),
            stroke,
          );

      // the same brackets turned inward, which is what leaving looks like
      case LdGlyph.fullscreenExit:
        canvas
          ..drawPath(
            Path()
              ..moveTo(9, 4)
              ..lineTo(9, 9)
              ..lineTo(4, 9),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(15, 9)
              ..lineTo(20, 9)
              ..lineTo(20, 4),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(20, 15)
              ..lineTo(15, 15)
              ..lineTo(15, 20),
            stroke,
          )
          ..drawPath(
            Path()
              ..moveTo(4, 15)
              ..lineTo(9, 15)
              ..lineTo(9, 20),
            stroke,
          );

      case LdGlyph.volume:
        canvas
          ..drawPath(
            Path()
              ..moveTo(4, 9.5)
              ..lineTo(7.5, 9.5)
              ..lineTo(11.5, 5.5)
              ..lineTo(11.5, 18.5)
              ..lineTo(7.5, 14.5)
              ..lineTo(4, 14.5)
              ..close(),
            stroke,
          )
          ..drawArc(
            const Rect.fromLTWH(13, 8, 6, 8),
            -1.0,
            2.0,
            false,
            stroke,
          );

      case LdGlyph.volumeOff:
        canvas
          ..drawPath(
            Path()
              ..moveTo(4, 9.5)
              ..lineTo(7.5, 9.5)
              ..lineTo(11.5, 5.5)
              ..lineTo(11.5, 18.5)
              ..lineTo(7.5, 14.5)
              ..lineTo(4, 14.5)
              ..close(),
            stroke,
          )
          ..drawLine(const Offset(15, 9.5), const Offset(20, 14.5), stroke)
          ..drawLine(const Offset(20, 9.5), const Offset(15, 14.5), stroke);

      case LdGlyph.image:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 5, 17, 14),
            const Radius.circular(2.6),
          ),
          stroke,
        );
        canvas.drawCircle(const Offset(9, 10), 1.7, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 17)
            ..lineTo(10, 12.5)
            ..lineTo(14, 16)
            ..lineTo(16.5, 13.8)
            ..lineTo(19.5, 17),
          stroke,
        );

      case LdGlyph.music:
        canvas.drawPath(
          Path()
            ..moveTo(9, 17)
            ..lineTo(9, 5.5)
            ..lineTo(19, 3.5)
            ..lineTo(19, 15),
          stroke,
        );
        canvas.drawCircle(const Offset(6.6, 17.2), 2.6, stroke);
        canvas.drawCircle(const Offset(16.6, 15.2), 2.6, stroke);

      case LdGlyph.code:
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 7.5)
            ..lineTo(3.5, 12)
            ..lineTo(8.5, 16.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15.5, 7.5)
            ..lineTo(20.5, 12)
            ..lineTo(15.5, 16.5),
          stroke,
        );
        canvas.drawLine(const Offset(13.5, 5), const Offset(10.5, 19), stroke);

      case LdGlyph.archive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 4.5, 17, 4.5),
            const Radius.circular(1.6),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5, 9)
            ..lineTo(5, 19.5)
            ..lineTo(19, 19.5)
            ..lineTo(19, 9),
          stroke,
        );
        canvas.drawLine(const Offset(10, 13), const Offset(14, 13), stroke);

      case LdGlyph.activity:
        canvas.drawPath(
          Path()
            ..moveTo(3, 12.5)
            ..lineTo(7.5, 12.5)
            ..lineTo(10, 6.5)
            ..lineTo(14, 18)
            ..lineTo(16.5, 12.5)
            ..lineTo(21, 12.5),
          stroke,
        );

      case LdGlyph.logout:
        canvas.drawPath(
          Path()
            ..moveTo(14, 5)
            ..lineTo(5.5, 5)
            ..lineTo(5.5, 19)
            ..lineTo(14, 19),
          stroke,
        );
        canvas.drawLine(const Offset(10, 12), const Offset(20, 12), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(16.5, 8.5)
            ..lineTo(20, 12)
            ..lineTo(16.5, 15.5),
          stroke,
        );

      case LdGlyph.qr:
        for (final origin in const <Offset>[
          Offset(4, 4),
          Offset(14, 4),
          Offset(4, 14),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(origin.dx, origin.dy, 6, 6),
              const Radius.circular(1.2),
            ),
            stroke,
          );
        }
        canvas.drawRect(const Rect.fromLTWH(14, 14, 2.5, 2.5), fill);
        canvas.drawRect(const Rect.fromLTWH(17.5, 17.5, 2.5, 2.5), fill);

      case LdGlyph.sort:
        canvas.drawLine(const Offset(4.5, 7), const Offset(15, 7), stroke);
        canvas.drawLine(const Offset(4.5, 12), const Offset(12, 12), stroke);
        canvas.drawLine(const Offset(4.5, 17), const Offset(9, 17), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(18, 6)
            ..lineTo(18, 18)
            ..moveTo(15.5, 15.5)
            ..lineTo(18, 18)
            ..lineTo(20.5, 15.5),
          stroke,
        );

      case LdGlyph.filter:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 6)
            ..lineTo(20.5, 6)
            ..lineTo(14, 13)
            ..lineTo(14, 19.5)
            ..lineTo(10, 17.5)
            ..lineTo(10, 13)
            ..close(),
          stroke,
        );

      case LdGlyph.arrowUp:
        canvas.drawLine(const Offset(12, 19), const Offset(12, 5), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 10.5)
            ..lineTo(12, 5)
            ..lineTo(17.5, 10.5),
          stroke,
        );

      case LdGlyph.arrowDown:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 13.5)
            ..lineTo(12, 19)
            ..lineTo(17.5, 13.5),
          stroke,
        );

      case LdGlyph.server:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 4, 17, 6.5),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 13.5, 17, 6.5),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawCircle(const Offset(7, 7.2), 1.1, fill);
        canvas.drawCircle(const Offset(7, 16.8), 1.1, fill);

      case LdGlyph.language:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawLine(const Offset(4, 12), const Offset(20, 12), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..quadraticBezierTo(16, 8, 16, 12)
            ..quadraticBezierTo(16, 16, 12, 20)
            ..quadraticBezierTo(8, 16, 8, 12)
            ..quadraticBezierTo(8, 8, 12, 4),
          stroke,
        );
    }

    canvas.restore();
  }

  Path _starPath() {
    const cx = 12.0;
    const cy = 12.2;
    const outer = 8.0;
    const inner = 3.4;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -1.5707963 + i * 0.3141593 * 2;
      final x = cx + radius * _cos(angle);
      final y = cy + radius * _sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  static double _cos(double radians) => _taylorCos(radians);
  static double _sin(double radians) => _taylorCos(radians - 1.5707963267948966);

  // a tiny cosine, so this painter pulls in no extra import for two calls
  static double _taylorCos(double x) {
    const twoPi = 6.283185307179586;
    var t = x % twoPi;
    if (t > 3.141592653589793) t -= twoPi;
    if (t < -3.141592653589793) t += twoPi;
    final t2 = t * t;
    return 1 - t2 / 2 + t2 * t2 / 24 - t2 * t2 * t2 / 720 +
        t2 * t2 * t2 * t2 / 40320;
  }

  @override
  bool shouldRepaint(_LdGlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.strokeWidth != strokeWidth;
}
