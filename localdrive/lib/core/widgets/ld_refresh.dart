import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import 'ld_spinner.dart';

/// Pull to refresh, drawn with the app's own dot ring rather than Material's
/// RefreshIndicator, so the gesture looks like the rest of the app.
class LdRefresh extends StatefulWidget {
  const LdRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;

  @override
  State<LdRefresh> createState() => _LdRefreshState();
}

class _LdRefreshState extends State<LdRefresh> {
  static const double _triggerDistance = 88;

  double _drag = 0;
  bool _refreshing = false;

  bool _onNotification(ScrollNotification notification) {
    if (!widget.enabled || _refreshing) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      setState(() {
        _drag = math.min(_triggerDistance * 1.4, _drag - notification.overscroll);
      });
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels > notification.metrics.minScrollExtent &&
        _drag > 0) {
      setState(() => _drag = 0);
      return false;
    }

    if (notification is ScrollEndNotification && _drag > 0) {
      if (_drag >= _triggerDistance) {
        unawaited(_run());
      } else {
        setState(() => _drag = 0);
      }
    }
    return false;
  }

  Future<void> _run() async {
    setState(() {
      _refreshing = true;
      _drag = _triggerDistance;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _drag = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_drag / _triggerDistance).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: Stack(
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.only(top: _refreshing ? 52 : 0),
            child: widget.child,
          ),
          if (_drag > 0 || _refreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: math.max(_drag, _refreshing ? 52 : 0),
                child: Center(
                  child: _refreshing
                      ? const LdSpinner(size: 26)
                      : Opacity(
                          opacity: progress,
                          child: Transform.rotate(
                            angle: progress * math.pi,
                            child: _PullMark(progress: progress),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The static ring the pull fills in before it becomes a live spinner.
class _PullMark extends StatelessWidget {
  const _PullMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(26),
      painter: _PullPainter(progress: progress),
    );
  }
}

class _PullPainter extends CustomPainter {
  const _PullPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    const dots = 8;
    final lit = (progress * dots).floor();

    for (var i = 0; i < dots; i++) {
      final angle = -math.pi / 2 + (i / dots) * 2 * math.pi;
      final offset = center +
          Offset(radius * math.cos(angle), radius * math.sin(angle));
      canvas.drawCircle(
        offset,
        size.width * 0.09,
        Paint()
          ..color = i < lit
              ? LdColors.accentPrimary
              : LdColors.wash(LdColors.foregroundSecondary, 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_PullPainter old) => old.progress != progress;
}
