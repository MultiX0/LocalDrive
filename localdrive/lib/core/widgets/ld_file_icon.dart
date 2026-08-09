import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import '../enums/file_category.dart';
import 'ld_icons.dart';

/// The layered file and folder icon.
///
/// These are not flat single path glyphs. Each is built from two or three
/// overlapping shapes, a back panel and a front panel at minimum, so it has
/// real visual weight while staying flat and fast: no gradients, no shadows.
class LdFileIcon extends StatelessWidget {
  const LdFileIcon({
    super.key,
    required this.category,
    this.size = 48,
    this.folderColor,
    this.peekThumbnails = const <ImageProvider>[],
    this.hovered = false,
    this.alwaysPeek = false,
  });

  final FileCategory category;
  final double size;

  /// the folder recolor choice; only ever changes the front panel's fill
  final String? folderColor;

  /// up to four thumbnails peeking out of a folder's opening
  final List<ImageProvider> peekThumbnails;

  /// on desktop the peek animates in on hover; on mobile it is always open
  final bool hovered;
  final bool alwaysPeek;

  @override
  Widget build(BuildContext context) {
    if (category.isFolder) {
      return _FolderIcon(
        size: size,
        color: folderColor,
        thumbnails: peekThumbnails,
        open: alwaysPeek || hovered,
        animate: !alwaysPeek,
      );
    }
    return _DocumentIcon(category: category, size: size);
  }
}

class _DocumentIcon extends StatelessWidget {
  const _DocumentIcon({required this.category, required this.size});

  final FileCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = category.tint;
    final back = LdColors.backPanel(tint);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          // back panel, a second sheet peeking out behind the first
          Positioned(
            left: size * 0.18,
            top: size * 0.08,
            child: Container(
              width: size * 0.6,
              height: size * 0.78,
              decoration: BoxDecoration(
                color: back,
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),
          // front panel with its folded corner
          Positioned(
            left: size * 0.1,
            top: size * 0.14,
            child: CustomPaint(
              size: Size(size * 0.66, size * 0.78),
              painter: _SheetPainter(fill: tint, fold: back),
            ),
          ),
          // the type glyph, small, sitting on the front panel
          Positioned(
            left: size * 0.24,
            top: size * 0.44,
            child: LdIcon(
              _glyphFor(category),
              size: size * 0.3,
              color: LdColors.backgroundPrimary,
              strokeWidth: 2.1,
            ),
          ),
        ],
      ),
    );
  }

  static LdGlyph _glyphFor(FileCategory category) => switch (category) {
        FileCategory.image => LdGlyph.image,
        FileCategory.video => LdGlyph.play,
        FileCategory.audio => LdGlyph.music,
        FileCategory.code => LdGlyph.code,
        FileCategory.archive => LdGlyph.archive,
        _ => LdGlyph.file,
      };
}

class _SheetPainter extends CustomPainter {
  const _SheetPainter({required this.fill, required this.fold});

  final Color fill;
  final Color fold;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.14;
    final foldSize = size.width * 0.34;

    final body = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - foldSize, 0)
      ..lineTo(size.width, foldSize)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
    canvas.drawPath(body, Paint()..color = fill);

    // the fold, the third shape that makes this read as paper
    final corner = Path()
      ..moveTo(size.width - foldSize, 0)
      ..lineTo(size.width, foldSize)
      ..lineTo(size.width - foldSize, foldSize)
      ..close();
    canvas.drawPath(corner, Paint()..color = fold);
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.fill != fill || old.fold != fold;
}

class _FolderIcon extends StatelessWidget {
  const _FolderIcon({
    required this.size,
    required this.color,
    required this.thumbnails,
    required this.open,
    required this.animate,
  });

  final double size;
  final String? color;
  final List<ImageProvider> thumbnails;
  final bool open;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final front = LdColors.folderSwatches[color ?? 'neutral'] ??
        LdColors.folderSwatches['neutral']!;
    // the back panel keeps a fixed darker neutral, so every folder reads as a
    // folder first and a color second
    const back = Color(0xFF3A3A3A);

    final peek = thumbnails.take(4).toList(growable: false);
    final tilt = open ? -0.09 : 0.0;
    final lift = open ? -size * 0.06 : 0.0;

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            // back panel with the tab
            Positioned(
              left: 0,
              top: size * 0.14,
              child: CustomPaint(
                size: Size(size, size * 0.74),
                painter: _FolderBackPainter(color: back),
              ),
            ),
            // the peeked contents, sitting between the panels
            if (peek.isNotEmpty)
              AnimatedPositioned(
                duration: animate ? LdMotion.hover : Duration.zero,
                curve: LdMotion.curve,
                left: size * 0.12,
                bottom: size * 0.24 + (open ? size * 0.08 : 0),
                child: AnimatedOpacity(
                  duration: animate ? LdMotion.hover : Duration.zero,
                  opacity: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < peek.length; i++)
                        Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(size * 0.05),
                            child: Image(
                              image: peek[i],
                              width: size * 0.18,
                              height: size * 0.24,
                              fit: BoxFit.cover,
                              // decoded no larger than it is drawn
                              filterQuality: FilterQuality.low,
                              errorBuilder: (context, _, _) => const SizedBox
                                  .shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // front panel, which tilts open a few degrees on hover
            AnimatedContainer(
              duration: animate ? LdMotion.hover : Duration.zero,
              curve: LdMotion.curve,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, lift, 0.0, 1.0)
                ..setEntry(3, 2, 0.0012)
                ..rotateX(tilt),
              transformAlignment: Alignment.bottomCenter,
              child: Container(
                width: size * 0.94,
                height: size * 0.56,
                margin: EdgeInsets.only(bottom: size * 0.1),
                decoration: BoxDecoration(
                  color: front,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(size * 0.08),
                    bottom: Radius.circular(size * 0.12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderBackPainter extends CustomPainter {
  const _FolderBackPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.09;
    final tabWidth = size.width * 0.42;
    final tabHeight = size.height * 0.16;

    final path = Path()
      ..moveTo(0, tabHeight + radius)
      ..quadraticBezierTo(0, tabHeight, radius, tabHeight)
      ..lineTo(tabWidth - radius, tabHeight)
      ..lineTo(tabWidth + size.width * 0.08, tabHeight)
      ..lineTo(tabWidth, 0)
      ..lineTo(radius, 0)
      ..quadraticBezierTo(0, 0, 0, radius)
      ..close();

    final body = Path()
      ..moveTo(0, tabHeight)
      ..lineTo(size.width - radius, tabHeight)
      ..quadraticBezierTo(size.width, tabHeight, size.width, tabHeight + radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
          size.width, size.height, size.width - radius, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..close();

    final paint = Paint()..color = color;
    canvas.drawPath(body, paint);

    // the fold, drawn as a small tab rising from the back panel
    final tab = Path()
      ..moveTo(0, tabHeight)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(tabWidth * 0.66, 0)
      ..lineTo(tabWidth, tabHeight)
      ..close();
    canvas.drawPath(tab, paint);
    canvas.drawPath(path, paint..color = color);
  }

  @override
  bool shouldRepaint(_FolderBackPainter old) => old.color != color;
}

/// The tile a browser renders: a real thumbnail if there is one, with the
/// layered type icon reduced to a corner badge, or the layered icon on its own
/// filling the tile when there is not.
class LdFileTile extends StatelessWidget {
  const LdFileTile({
    super.key,
    required this.category,
    required this.hasThumbnail,
    this.thumbnail,
    this.folderColor,
    this.peekThumbnails = const <ImageProvider>[],
    this.hovered = false,
    this.alwaysPeek = false,
    this.size = 96,
  });

  final FileCategory category;
  final bool hasThumbnail;
  final ImageProvider? thumbnail;
  final String? folderColor;
  final List<ImageProvider> peekThumbnails;
  final bool hovered;
  final bool alwaysPeek;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (category.isFolder || !hasThumbnail || thumbnail == null) {
      return Container(
        decoration: BoxDecoration(
          color: LdColors.backgroundElevated,
          borderRadius: LdRadii.tileRadius,
        ),
        alignment: Alignment.center,
        child: LdFileIcon(
          category: category,
          size: size * 0.52,
          folderColor: folderColor,
          peekThumbnails: peekThumbnails,
          hovered: hovered,
          alwaysPeek: alwaysPeek,
        ),
      );
    }

    return ClipRRect(
      borderRadius: LdRadii.tileRadius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image(
            image: thumbnail!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, _, _) => Container(
              color: LdColors.backgroundElevated,
              alignment: Alignment.center,
              child: LdFileIcon(category: category, size: size * 0.5),
            ),
          ),
          // a still frame from a video looks the same as a photo, so this
          // marks it. Centered, where a play control always sits.
          if (category == FileCategory.video)
            const Center(child: _PlayBadge()),
          // the type badge sits bottom right, opposite the owner avatar
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: LdColors.backgroundPrimary.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LdFileIcon(category: category, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}


/// The play symbol over a video thumbnail.
class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        // dark enough to read over a bright frame, and still showing the frame
        // through, so it reads as an overlay rather than a hole in the picture
        color: LdColors.backgroundPrimary.withValues(alpha: 0.62),
        shape: BoxShape.circle,
        border: Border.all(color: LdColors.foregroundPrimary.withValues(alpha: 0.5)),
      ),
      child: const Center(
        child: LdIcon(LdGlyph.play, size: 18, color: LdColors.foregroundPrimary),
      ),
    );
  }
}
