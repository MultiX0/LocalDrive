import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../imports.dart';
import 'media_bits.dart';

/// The video player.
///
/// Built on libmpv rather than the platform's own decoder. video_player has no
/// Windows implementation at all, and the community one hands the URL to Media
/// Foundation, which pulled the whole file down before showing a frame: a clip
/// on a server running on the same machine took seconds to start. libmpv opens
/// a network stream, starts on the first keyframe, and seeks by asking for the
/// byte range it needs, which is what the server has always served.
///
/// The chrome is the app's own. A player that arrives with someone else's
/// buttons is the most obvious seam a person can find.
class VideoView extends StatefulWidget {
  const VideoView({
    super.key,
    this.url = '',
    this.localPath = '',
    this.headers = const <String, String>{},
  });

  final String url;
  final String localPath;
  final Map<String, String> headers;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late final Player _player;
  late final VideoController _controller;

  bool _fullscreen = false;
  Object? _error;
  StreamSubscription<String>? _errors;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _errors = _player.stream.error.listen((message) {
      if (mounted) setState(() => _error = message);
    });

    final source = widget.localPath.isNotEmpty
        ? Media(widget.localPath)
        // the token rides in the query string already, so no headers are
        // needed; passing them anyway keeps a signed url working if that
        // ever changes
        : Media(widget.url, httpHeaders: widget.headers);
    unawaited(_player.open(source));
  }

  @override
  void dispose() {
    unawaited(_errors?.cancel());
    unawaited(_player.dispose());
    super.dispose();
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

    return _Chrome(
      player: _player,
      controller: _controller,
      isFullscreen: _fullscreen,
      onToggleFullscreen: _toggleFullscreen,
    );
  }

  /// Full screen without a second player.
  ///
  /// Building another one would restart from the beginning and open the stream
  /// twice. The same player goes into an opaque route on top, so leaving lands
  /// exactly where it was, still playing.
  void _toggleFullscreen() {
    if (_fullscreen) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _fullscreen = true);
    unawaited(
      Navigator.of(context)
          .push(
            PageRouteBuilder<void>(
              opaque: true,
              pageBuilder: (routeContext, _, _) => Scaffold(
                backgroundColor: LdColors.backgroundPrimary,
                body: _Chrome(
                  player: _player,
                  controller: _controller,
                  isFullscreen: true,
                  onToggleFullscreen: () => Navigator.of(routeContext).pop(),
                ),
              ),
            ),
          )
          .then((_) {
            if (mounted) setState(() => _fullscreen = false);
          }),
    );
  }
}

/// The picture with the app's controls over it.
class _Chrome extends StatefulWidget {
  const _Chrome({
    required this.player,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final Player player;
  final VideoController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  State<_Chrome> createState() => _ChromeState();
}

class _ChromeState extends State<_Chrome> {
  bool _visible = true;
  bool _scrubbing = false;
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _wake() {
    _idle?.cancel();
    if (!mounted) return;
    setState(() => _visible = true);
    _idle = Timer(const Duration(seconds: 3), () {
      // never hide while paused: a paused video with no controls looks broken
      if (!mounted || _scrubbing || !widget.player.state.playing) return;
      setState(() => _visible = false);
    });
  }

  void _togglePlay() {
    final state = widget.player.state;
    if (state.playing) {
      unawaited(widget.player.pause());
    } else {
      // pressing play at the very end replays rather than sitting there
      if (state.duration > Duration.zero &&
          state.position >=
              state.duration - const Duration(milliseconds: 200)) {
        unawaited(widget.player.seek(Duration.zero));
      }
      unawaited(widget.player.play());
    }
    _wake();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _wake(),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(
            color: LdColors.backgroundPrimary,
            child: Video(
              controller: widget.controller,
              controls: NoVideoControls,
              fill: LdColors.backgroundPrimary,
            ),
          ),
          // a tap anywhere on the picture plays or pauses
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: const SizedBox.expand(),
            ),
          ),
          AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: LdMotion.standard,
            curve: LdMotion.curve,
            child: IgnorePointer(
              ignoring: !_visible,
              child: _Bar(
                player: widget.player,
                isFullscreen: widget.isFullscreen,
                onToggleFullscreen: widget.onToggleFullscreen,
                onTogglePlay: _togglePlay,
                onScrubStart: () => _scrubbing = true,
                onScrubEnd: () {
                  _scrubbing = false;
                  _wake();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.player,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onTogglePlay,
    required this.onScrubStart,
    required this.onScrubEnd,
  });

  final Player player;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePlay;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        // a wash rather than a solid bar, so the bottom of the picture is
        // never cut off by a rectangle of chrome
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xE6000000), Color(0x00000000)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 34, 16, 16),
          child: StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, positionSnapshot) {
              final total = player.state.duration;
              var position = positionSnapshot.data ?? player.state.position;
              if (position > total) position = total;
              final left = total - position;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MediaScrubber(
                    position: position,
                    total: total,
                    buffer: player.state.buffer,
                    onStart: onScrubStart,
                    onSeek: (to) => unawaited(player.seek(to)),
                    onEnd: onScrubEnd,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      StreamBuilder<bool>(
                        stream: player.stream.playing,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? player.state.playing;
                          return LdUtilityButton(
                            glyph: playing ? LdGlyph.pause : LdGlyph.play,
                            tooltip: playing
                                ? l10n.actionPause
                                : l10n.actionPlay,
                            onPressed: onTogglePlay,
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      // elapsed and total, then what is left, which is the
                      // number people look for when deciding to keep watching
                      Text(
                        mediaClock(position),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        '  /  ${mediaClock(total)}',
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(color: LdColors.foregroundSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '-${mediaClock(left)}',
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(color: LdColors.foregroundSecondary),
                      ),
                      if (isPointerPlatform) ...<Widget>[
                        const SizedBox(width: 18),
                        StreamBuilder<double>(
                          stream: player.stream.volume,
                          builder: (context, snapshot) => VolumeControl(
                            volume: snapshot.data ?? player.state.volume,
                            onChanged: (v) => unawaited(player.setVolume(v)),
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                      LdUtilityButton(
                        glyph: isFullscreen
                            ? LdGlyph.fullscreenExit
                            : LdGlyph.fullscreen,
                        tooltip: isFullscreen
                            ? l10n.actionExitFullscreen
                            : l10n.actionFullscreen,
                        onPressed: onToggleFullscreen,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
