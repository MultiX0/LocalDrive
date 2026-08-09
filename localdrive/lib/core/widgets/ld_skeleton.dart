import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';

/// Branded loading placeholders.
///
/// A spinner is right when there is nothing to stand in for. When the shape of
/// what is coming is already known, a skeleton in the app's own surfaces reads
/// as the content arriving rather than as a wait, so lists and grids use these
/// instead of a bare spinner.
class LdSkeleton extends StatefulWidget {
  const LdSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  /// a circle, for an avatar or a utility button placeholder
  const LdSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<LdSkeleton> createState() => _LdSkeletonState();
}

class _LdSkeletonState extends State<LdSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
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
        builder: (context, _) {
          // a slow sweep in the brand's own greys, never a bright shimmer
          final position = _controller.value * 2 - 1;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle
                  ? null
                  : BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(position - 1, 0),
                end: Alignment(position + 1, 0),
                colors: const <Color>[
                  Color(0xFF1C1C1C),
                  Color(0xFF2A2A2A),
                  Color(0xFF1C1C1C),
                ],
                stops: const <double>[0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The loading stand-in for a file list, matching the real rows exactly so
/// nothing shifts when the content lands.
class LdListSkeleton extends StatelessWidget {
  const LdListSkeleton({super.key, this.rows = 7, this.padding});

  final int rows;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rows,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: <Widget>[
            const LdSkeleton(width: 44, height: 44, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LdSkeleton(width: index.isEven ? 180 : 132, height: 13),
                  const SizedBox(height: 8),
                  const LdSkeleton(width: 84, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading stand-in for the grid view.
class LdGridSkeleton extends StatelessWidget {
  const LdGridSkeleton({
    super.key,
    required this.columns,
    this.tiles = 12,
    this.padding,
  });

  final int columns;
  final int tiles;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: tiles,
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(
            child: LdSkeleton(
              width: double.infinity,
              height: double.infinity,
              radius: LdRadii.tile,
            ),
          ),
          const SizedBox(height: 10),
          LdSkeleton(width: index.isEven ? 90 : 64, height: 12),
        ],
      ),
    );
  }
}

/// The loading stand-in for a settings or detail screen.
class LdCardSkeleton extends StatelessWidget {
  const LdCardSkeleton({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: LdColors.backgroundElevated,
          borderRadius: LdRadii.cardRadius,
          border: Border.all(color: LdColors.strokeOutline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            LdSkeleton(width: 140, height: 14),
            SizedBox(height: 14),
            LdSkeleton(width: double.infinity, height: 8, radius: 4),
            SizedBox(height: 12),
            LdSkeleton(width: 200, height: 11),
          ],
        ),
      ),
    );
  }
}
