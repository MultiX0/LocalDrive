import 'dart:math' as math;

import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../../../imports.dart';
import 'media_bits.dart';

/// The inline audio player.
///
/// Same engine as the video player, so a track streams from the server by byte
/// range instead of being downloaded whole, and behaves the same way once it is
/// playing: same scrubber, same clock, same volume control on a desktop.
///
/// There is nothing to look at in an audio file, so the screen becomes the
/// control: a large disc that turns while the track plays and settles when it
/// pauses, with a scrubbable bar under it. The disc is drawn, not an asset, so
/// it tints to the file type and costs nothing to ship.
class AudioView extends StatefulWidget {
  const AudioView({
    super.key,
    required this.name,
    this.url = '',
    this.headers = const <String, String>{},
    this.localPath = '',
  }) : assert(
         url != '' || localPath != '',
         'a player needs either a url to stream or a file to open',
       );

  final String url;
  final Map<String, String> headers;
  final String name;

  /// set when this file is kept on the device, in which case nothing is
  /// fetched and playback starts from disk
  final String localPath;

  @override
  State<AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<AudioView>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final AnimationController _spin;
  final List<StreamSubscription<Object?>> _subs =
      <StreamSubscription<Object?>>[];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  double _volume = 100;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _player = Player();

    // one subscription per fact, held in state. Reading player.state inside a
    // builder driven by a different stream is how a scrubber ends up with a
    // duration of zero and every seek computes to the start of the track.
    _subs.addAll(<StreamSubscription<Object?>>[
      _player.stream.position.listen((v) => _set(() => _position = v)),
      _player.stream.duration.listen((v) => _set(() => _duration = v)),
      _player.stream.buffer.listen((v) => _set(() => _buffer = v)),
      _player.stream.buffering.listen((v) => _set(() => _buffering = v)),
      _player.stream.volume.listen((v) => _set(() => _volume = v)),
      _player.stream.playing.listen((v) {
        _set(() => _playing = v);
        if (v) {
          _spin.repeat();
        } else {
          _spin.stop();
        }
      }),
      _player.stream.error.listen((message) => _set(() => _error = message)),
    ]);

    unawaited(
      _player.open(
        widget.localPath.isNotEmpty
            ? Media(widget.localPath)
            : Media(widget.url, httpHeaders: widget.headers),
      ),
    );
  }

  void _set(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _spin.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  void _toggle() {
    if (_playing) {
      unawaited(_player.pause());
      return;
    }
    // a finished track restarts rather than doing nothing
    if (_duration > Duration.zero &&
        _position >= _duration - const Duration(milliseconds: 250)) {
      unawaited(_player.seek(Duration.zero));
    }
    unawaited(_player.play());
  }

  void _nudge(Duration by) {
    final target = _position + by;
    _seek(target);
  }

  void _seek(Duration to) {
    if (_duration <= Duration.zero) return;
    final clamped = to < Duration.zero
        ? Duration.zero
        : (to > _duration ? _duration : to);
    // move the handle immediately so it stays under the pointer rather than
    // snapping back until the player reports its new position
    setState(() => _position = clamped);
    unawaited(_player.seek(clamped));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    if (_error != null) {
      return LdErrorState(
        kind: LdErrorKind.unexpected,
        title: l10n.errorUnexpectedTitle,
        message: l10n.errorUnexpectedBody,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                  size: const Size.square(220),
                  painter: _DiscPainter(turns: _spin.value),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                widget.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 26),
              MediaScrubber(
                position: _position,
                total: _duration,
                buffer: _buffer,
                onStart: () {},
                onSeek: _seek,
                onEnd: () {},
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(
                    mediaClock(_position),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    '-${mediaClock(_duration - _position)}',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: LdColors.foregroundSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  LdUtilityButton(
                    glyph: LdGlyph.arrowUp,
                    tooltip: l10n.previewSkipBack,
                    onPressed: () => _nudge(const Duration(seconds: -15)),
                  ),
                  const SizedBox(width: 22),
                  _PlayButton(
                    playing: _playing,
                    busy: _buffering && !_playing,
                    onPressed: _toggle,
                  ),
                  const SizedBox(width: 22),
                  LdUtilityButton(
                    glyph: LdGlyph.arrowDown,
                    tooltip: l10n.previewSkipForward,
                    onPressed: () => _nudge(const Duration(seconds: 15)),
                  ),
                ],
              ),
              // a phone has hardware volume keys and no room to spare; a
              // desktop has neither of those things
              if (isPointerPlatform) ...<Widget>[
                const SizedBox(height: 22),
                Center(
                  child: VolumeControl(
                    volume: _volume,
                    onChanged: (v) => unawaited(_player.setVolume(v)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.busy,
    required this.onPressed,
  });

  final bool playing;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LdTappable(
      onTap: busy ? null : onPressed,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: LdColors.accentPrimary,
          shape: BoxShape.circle,
        ),
        child: busy
            ? const LdSpinner(size: 22, color: LdColors.foregroundPrimary)
            : CustomPaint(
                size: const Size.square(26),
                painter: _TransportPainter(playing: playing),
              ),
      ),
    );
  }
}

/// Play and pause, drawn rather than pulled from the icon font, because these
/// two are the only glyphs in the app that need to morph into each other.
class _TransportPainter extends CustomPainter {
  const _TransportPainter({required this.playing});

  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LdColors.foregroundPrimary
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    if (playing) {
      final barWidth = w * 0.24;
      final gap = w * 0.16;
      final left = (w - barWidth * 2 - gap) / 2;
      final radius = Radius.circular(barWidth * 0.25);
      canvas
        ..drawRRect(RRect.fromLTRBR(left, 0, left + barWidth, h, radius), paint)
        ..drawRRect(
          RRect.fromLTRBR(left + barWidth + gap, 0, w - left, h, radius),
          paint,
        );
      return;
    }

    // a triangle nudged right, so it reads as centered inside the circle
    final path = Path()
      ..moveTo(w * 0.16, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w * 0.16, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TransportPainter oldDelegate) =>
      oldDelegate.playing != playing;
}

/// The turning disc. Concentric grooves, a tinted label, and one bright mark
/// so the rotation is visible at all.
class _DiscPainter extends CustomPainter {
  const _DiscPainter({required this.turns});

  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = LdColors.backgroundElevated,
    );

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final t = i / 8;
      groove.color = LdColors.strokeOutline.withValues(alpha: 0.25 + t * 0.25);
      canvas.drawCircle(center, radius * (0.42 + t * 0.55), groove);
    }

    canvas.drawCircle(
      center,
      radius * 0.36,
      Paint()..color = LdColors.fileMedia.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      center,
      radius * 0.07,
      Paint()..color = LdColors.backgroundPrimary,
    );

    // the one mark that makes the spin readable
    final angle = turns * 2 * math.pi;
    final markStart =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.44);
    final markEnd =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.94);
    canvas.drawLine(
      markStart,
      markEnd,
      Paint()
        ..color = LdColors.accentPrimary
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DiscPainter oldDelegate) => oldDelegate.turns != turns;
}
