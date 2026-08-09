// Renders the raster copies of the logo mark that the platform toolchains
// need and that cannot be drawn at runtime: the app icon, the Android adaptive
// icon foreground, and the native splash image.
//
// The geometry here is the same geometry LdLogo draws in the app and mark.svg
// holds, kept in one shape so the icon, the splash, and the running app can
// never disagree about what the mark looks like.
//
//   dart run tool/generate_logo_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart';

/// The mark is authored on a 64 by 64 box, the same as the svg.
const double viewBox = 64;

// solid layered panels, not a thin outline
const int colorBack = 0xFF2A6FD6;
const int colorSheet = 0xFFDCE3EE;
const int colorFront = 0xFF4C8DFF;
const int colorMark = 0xFFFFFFFF;
const int colorBackground = 0xFF141414;

void main(List<String> args) {
  final outputDir = Directory('assets/logo');
  outputDir.createSync(recursive: true);

  // the icon source: the mark on the brand background
  _write(
    '${outputDir.path}/mark_1024.png',
    _renderMark(size: 1024, scale: 0.66, background: colorBackground),
  );

  // the adaptive icon foreground: transparent, inset further, because Android
  // masks the outer third away
  _write(
    '${outputDir.path}/mark_foreground_1024.png',
    _renderMark(size: 1024, scale: 0.42, background: null),
  );

  // the splash: transparent, so it sits on the colour the splash config sets
  _write(
    '${outputDir.path}/mark_splash.png',
    _renderMark(size: 512, scale: 0.60, background: null),
  );

  // the tray icon: small, transparent, and rendered at the sizes each
  // desktop asks for. Windows insists on a real .ico, which is a container
  // holding several sizes rather than one image scaled at runtime
  _write(
    '${outputDir.path}/tray.png',
    _renderMark(size: 64, scale: 0.86, background: null),
  );
  _writeIco(
    '${outputDir.path}/tray.ico',
    <int>[16, 24, 32, 48, 64].map(
      (size) => _renderMark(size: size, scale: 0.86, background: null),
    ).toList(),
  );

  stdout.writeln('wrote the icon, the adaptive foreground, the splash mark, '
      'and the tray icons');
}

/// A minimal ICO container: a header, one directory entry per size, and each
/// image stored as a PNG payload, which every Windows since Vista accepts.
void _writeIco(String path, List<Image> images) {
  final entries = images.map(encodePng).toList();

  final header = BytesBuilder()
    ..add(<int>[0, 0]) // reserved
    ..add(<int>[1, 0]) // type: icon
    ..add(<int>[images.length & 0xFF, images.length >> 8]);

  // the payloads start after the header and the whole directory
  var offset = 6 + images.length * 16;
  final directory = BytesBuilder();
  for (var i = 0; i < images.length; i++) {
    final image = images[i];
    final bytes = entries[i];
    directory
      ..addByte(image.width >= 256 ? 0 : image.width)
      ..addByte(image.height >= 256 ? 0 : image.height)
      ..addByte(0) // palette size, zero for a true colour image
      ..addByte(0) // reserved
      ..add(<int>[1, 0]) // colour planes
      ..add(<int>[32, 0]) // bits per pixel
      ..add(_le32(bytes.length))
      ..add(_le32(offset));
    offset += bytes.length;
  }

  final out = BytesBuilder()
    ..add(header.takeBytes())
    ..add(directory.takeBytes());
  for (final bytes in entries) {
    out.add(bytes);
  }

  File(path).writeAsBytesSync(out.takeBytes());
  stdout.writeln('  $path');
}

List<int> _le32(int value) => <int>[
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

void _write(String path, Image image) {
  File(path).writeAsBytesSync(encodePng(image));
  stdout.writeln('  $path');
}

/// Draws the mark centered in a square canvas.
///
/// `scale` is how much of the canvas the mark occupies, which is what gives
/// the icon and the adaptive foreground their different safe areas.
Image _renderMark({
  required int size,
  required double scale,
  required int? background,
}) {
  // drawn at four times the final size and averaged down, which is the
  // cheapest way to get clean edges without a real rasterizer
  const int supersample = 4;
  final canvas = size * supersample;
  final image = Image(width: canvas, height: canvas, numChannels: 4);

  if (background != null) {
    fill(image, color: _color(background));
  } else {
    fill(image, color: ColorRgba8(0, 0, 0, 0));
  }

  final unit = canvas * scale / viewBox;
  final offset = (canvas - viewBox * unit) / 2;
  _P at(double px, double py) => _P(offset + px * unit, offset + py * unit);

  // logo-back: the folder back and its raised tab
  _fill(image, <_P>[
    at(10, 12),
    at(24, 12),
    at(29, 18),
    at(54, 18),
    ..._quad(at(54, 18), at(58, 18), at(58, 22)),
    at(58, 46),
    ..._quad(at(58, 46), at(58, 50), at(54, 50)),
    at(10, 50),
    ..._quad(at(10, 50), at(6, 50), at(6, 46)),
    at(6, 16),
    ..._quad(at(6, 16), at(6, 12), at(10, 12)),
  ], colorBack);

  // logo-sheet: the contents peeking out of the opening
  _fill(image, <_P>[
    at(14, 21),
    at(50, 21),
    ..._quad(at(50, 21), at(52, 21), at(52, 23)),
    at(52, 44),
    at(12, 44),
    at(12, 23),
    ..._quad(at(12, 23), at(12, 21), at(14, 21)),
  ], colorSheet);

  // logo-front: the brightest shape, over everything
  _fill(image, <_P>[
    at(10, 26),
    at(54, 26),
    ..._quad(at(54, 26), at(58, 26), at(58, 30)),
    at(58, 46),
    ..._quad(at(58, 46), at(58, 50), at(54, 50)),
    at(10, 50),
    ..._quad(at(10, 50), at(6, 50), at(6, 46)),
    at(6, 30),
    ..._quad(at(6, 30), at(6, 26), at(10, 26)),
  ], colorFront);

  // logo-arc: the sync arc on the front panel
  final arc = <_P>[];
  const start = math.pi * 0.72;
  const sweep = math.pi * 1.56;
  for (var i = 0; i <= 60; i++) {
    final angle = start + sweep * (i / 60);
    arc.add(at(32 + 8 * math.cos(angle), 38 + 8 * math.sin(angle)));
  }
  _stroke(image, arc, 3 * unit, colorMark);

  // logo-node: the connection dot at the centre of the arc
  _disc(image, at(32, 38), 3.2 * unit, colorMark);

  return copyResize(
    image,
    width: size,
    height: size,
    interpolation: Interpolation.average,
  );
}

/// One point, in canvas pixels.
class _P {
  const _P(this.x, this.y);
  final double x;
  final double y;
}

/// Samples a quadratic curve, so a rounded corner reads as one.
List<_P> _quad(_P from, _P control, _P to, {int steps = 12}) {
  final out = <_P>[];
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    final inverse = 1 - t;
    out.add(_P(
      inverse * inverse * from.x + 2 * inverse * t * control.x + t * t * to.x,
      inverse * inverse * from.y + 2 * inverse * t * control.y + t * t * to.y,
    ));
  }
  return out;
}

/// Scanline fills a closed polygon. The supersample above smooths its edge.
void _fill(Image image, List<_P> polygon, int color) {
  if (polygon.length < 3) return;
  final paint = _color(color);

  var minY = polygon.first.y;
  var maxY = polygon.first.y;
  for (final point in polygon) {
    minY = math.min(minY, point.y);
    maxY = math.max(maxY, point.y);
  }
  final firstRow = math.max(0, minY.floor());
  final lastRow = math.min(image.height - 1, maxY.ceil());

  for (var row = firstRow; row <= lastRow; row++) {
    final centre = row + 0.5;
    final crossings = <double>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.y <= centre && b.y > centre) || (b.y <= centre && a.y > centre)) {
        crossings.add(a.x + (centre - a.y) / (b.y - a.y) * (b.x - a.x));
      }
    }
    if (crossings.isEmpty) continue;
    crossings.sort();
    for (var i = 0; i + 1 < crossings.length; i += 2) {
      final from = math.max(0, crossings[i].round());
      final to = math.min(image.width - 1, crossings[i + 1].round());
      for (var column = from; column <= to; column++) {
        image.setPixel(column, row, paint);
      }
    }
  }
}

/// Strokes a polyline by stamping discs along it, which gives round caps and
/// round joins for free.
void _stroke(Image image, List<_P> points, double width, int color) {
  if (points.isEmpty) return;
  final radius = width / 2;

  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = math.max(1, (distance / (radius * 0.35)).ceil());
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      _disc(image, _P(a.x + dx * t, a.y + dy * t), radius, color);
    }
  }
  _disc(image, points.last, radius, color);
}

/// A filled circle.
void _disc(Image image, _P center, double radius, int color) {
  final paint = _color(color);
  final minX = math.max(0, (center.x - radius).floor());
  final maxX = math.min(image.width - 1, (center.x + radius).ceil());
  final minY = math.max(0, (center.y - radius).floor());
  final maxY = math.min(image.height - 1, (center.y + radius).ceil());
  final squared = radius * radius;

  for (var py = minY; py <= maxY; py++) {
    for (var px = minX; px <= maxX; px++) {
      final dx = px - center.x;
      final dy = py - center.y;
      if (dx * dx + dy * dy <= squared) {
        image.setPixel(px, py, paint);
      }
    }
  }
}

ColorRgba8 _color(int argb) => ColorRgba8(
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
      (argb >> 24) & 0xFF,
    );
