import '../../../imports.dart';

/// The seek bar: a thin track, what has buffered behind it, and a handle.
///
/// Shared by the video player and the audio player, because a person who has
/// learned to scrub one has learned to scrub the other, and two scrubbers that
/// behave differently in the same app is a small betrayal.
class MediaScrubber extends StatefulWidget {
  const MediaScrubber({
    super.key,
    required this.position,
    required this.total,
    required this.buffer,
    required this.onStart,
    required this.onSeek,
    required this.onEnd,
  });

  final Duration position;
  final Duration total;
  final Duration buffer;
  final VoidCallback onStart;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onEnd;

  @override
  State<MediaScrubber> createState() => _MediaScrubberState();
}

class _MediaScrubberState extends State<MediaScrubber> {
  double? _dragging;

  double get _fraction {
    if (_dragging != null) return _dragging!;
    final total = widget.total.inMilliseconds;
    if (total <= 0) return 0;
    return (widget.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _to(double fraction, {required bool commit}) {
    setState(() => _dragging = fraction.clamp(0.0, 1.0));
    if (!commit) return;
    widget.onSeek(
      Duration(milliseconds: (widget.total.inMilliseconds * _dragging!).round()),
    );
    setState(() => _dragging = null);
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double at(Offset local) => width <= 0 ? 0 : local.dx / width;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            widget.onStart();
            _to(at(d.localPosition), commit: false);
          },
          onHorizontalDragUpdate: (d) => _to(at(d.localPosition), commit: false),
          onHorizontalDragEnd: (_) => _to(_fraction, commit: true),
          // a tap on the track jumps there, which is how a scrubber gets used
          // far more often than it gets dragged
          onTapDown: (d) {
            widget.onStart();
            _to(at(d.localPosition), commit: true);
          },
          child: SizedBox(
            height: 22,
            child: Center(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  _track(LdColors.backgroundElevated),
                  if (widget.total.inMilliseconds > 0)
                    FractionallySizedBox(
                      widthFactor: (widget.buffer.inMilliseconds /
                              widget.total.inMilliseconds)
                          .clamp(0.0, 1.0),
                      child: _track(LdColors.strokeOutline),
                    ),
                  FractionallySizedBox(
                    widthFactor: _fraction,
                    child: _track(LdColors.accentPrimary),
                  ),
                  Align(
                    alignment: Alignment(_fraction * 2 - 1, 0),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: LdColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _track(Color color) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// Volume, as a speaker that mutes on click and a short slider beside it.
///
/// Only on a pointer platform. A phone has hardware buttons for this and the
/// space is better spent on the picture; putting a 90 point slider in a phone
/// player is how a control bar stops fitting.
class VolumeControl extends StatefulWidget {
  const VolumeControl({
    super.key,
    required this.volume,
    required this.onChanged,
  });

  /// 0 to 100, which is what libmpv works in
  final double volume;
  final ValueChanged<double> onChanged;

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  /// what to go back to when the speaker is clicked again, so muting is not a
  /// one way trip that loses the level someone had set
  double _restore = 100;

  void _toggleMute() {
    if (widget.volume > 0) {
      _restore = widget.volume;
      widget.onChanged(0);
      return;
    }
    widget.onChanged(_restore <= 0 ? 100 : _restore);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final muted = widget.volume <= 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LdUtilityButton(
          glyph: muted ? LdGlyph.volumeOff : LdGlyph.volume,
          tooltip: muted ? l10n.actionUnmute : l10n.actionMute,
          onPressed: _toggleMute,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 90,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              void set(Offset local) {
                if (width <= 0) return;
                widget.onChanged((local.dx / width).clamp(0.0, 1.0) * 100);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => set(d.localPosition),
                onHorizontalDragStart: (d) => set(d.localPosition),
                onHorizontalDragUpdate: (d) => set(d.localPosition),
                child: SizedBox(
                  height: 22,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: LdColors.backgroundElevated,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (widget.volume / 100).clamp(0.0, 1.0),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: LdColors.foregroundPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(
                            (widget.volume / 100).clamp(0.0, 1.0) * 2 - 1,
                            0,
                          ),
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: LdColors.foregroundPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Hours only when there are hours, so a two minute clip does not read 0:02:14.
String mediaClock(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  if (d.inHours <= 0) return '$minutes:$seconds';
  return '${d.inHours}:$minutes:$seconds';
}
