import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import 'ld_button.dart';
import 'ld_avatar.dart';
import 'ld_icons.dart';

/// The send animation: the item's icon arcs across to the person's avatar,
/// which then rings once to accept it.
///
/// The grant underneath is an ordinary permission change against the server.
/// This is the part that makes it feel like handing something over, which is
/// what people expect when the other person is standing next to them.
class LdSendFlight extends StatefulWidget {
  const LdSendFlight({
    super.key,
    required this.from,
    required this.to,
    required this.glyph,
    required this.name,
    required this.seed,
    this.onDone,
  });

  /// where the item is now, in the overlay's coordinates
  final Offset from;

  /// where the person's avatar is
  final Offset to;
  final LdGlyph glyph;
  final String name;
  final String seed;
  final VoidCallback? onDone;

  /// Plays the flight over the whole screen, then cleans itself up.
  static Future<void> play(
    BuildContext context, {
    required Offset from,
    required Offset to,
    required LdGlyph glyph,
    required String name,
    required String seed,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    final done = Completer<void>();
    entry = OverlayEntry(
      builder: (context) => LdSendFlight(
        from: from,
        to: to,
        glyph: glyph,
        name: name,
        seed: seed,
        onDone: () {
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }

  @override
  State<LdSendFlight> createState() => _LdSendFlightState();
}

class _LdSendFlightState extends State<LdSendFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // the item travels for the first two thirds, the avatar rings for
          // the last third, so the two read as cause and effect
          final flight = Curves.easeInOutCubic.transform(
            (_controller.value / 0.66).clamp(0.0, 1.0),
          );
          final landing = ((_controller.value - 0.66) / 0.34).clamp(0.0, 1.0);

          final position = _arc(widget.from, widget.to, flight);
          final scale = 1 - 0.45 * flight;

          return Stack(
            children: <Widget>[
              if (landing > 0)
                Positioned(
                  left: widget.to.dx - 44,
                  top: widget.to.dy - 44,
                  child: _AcceptRing(progress: landing, name: widget.name, seed: widget.seed),
                ),
              if (flight < 1)
                Positioned(
                  left: position.dx - 22,
                  top: position.dy - 22,
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: 1 - 0.2 * flight,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: LdColors.accentPrimary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: LdColors.accentPrimary
                                  .withValues(alpha: 0.35),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Center(
                          child: LdIcon(
                            widget.glyph,
                            size: 22,
                            color: LdColors.foregroundPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// A curve rather than a straight line, lifted perpendicular to the path, so
  /// it reads as thrown rather than dragged.
  static Offset _arc(Offset from, Offset to, double t) {
    final direct = Offset.lerp(from, to, t)!;
    final delta = to - from;
    final length = delta.distance;
    if (length < 1) return direct;
    final normal = Offset(-delta.dy, delta.dx) / length;
    final lift = math.sin(t * math.pi) * math.min(120, length * 0.28);
    return direct + normal * lift;
  }
}

/// The ring that closes around the recipient's avatar as the item lands.
class _AcceptRing extends StatelessWidget {
  const _AcceptRing({
    required this.progress,
    required this.name,
    required this.seed,
  });

  final double progress;
  final String name;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.scale(
            scale: 0.7 + 0.3 * eased,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LdColors.fileSpreadsheet
                      .withValues(alpha: 0.9 * (1 - progress * 0.4)),
                  width: 3,
                ),
              ),
            ),
          ),
          LdAvatar(name: name, seed: seed, size: 52),
          if (progress > 0.5)
            Opacity(
              opacity: ((progress - 0.5) / 0.5).clamp(0.0, 1.0),
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: LdColors.fileSpreadsheet,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: LdIcon(
                    LdGlyph.check,
                    size: 15,
                    color: LdColors.backgroundPrimary,
                    strokeWidth: 2.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the receiving device shows: a warm, specific toast rather than a
/// generic notification, with the item riding in beneath the sender's face.
class LdReceivedCard extends StatefulWidget {
  const LdReceivedCard({
    super.key,
    required this.senderName,
    required this.senderSeed,
    required this.itemName,
    required this.glyph,
    this.onOpen,
    this.openLabel,
  });

  final String senderName;
  final String senderSeed;
  final String itemName;
  final LdGlyph glyph;
  final VoidCallback? onOpen;
  final String? openLabel;

  @override
  State<LdReceivedCard> createState() => _LdReceivedCardState();
}

class _LdReceivedCardState extends State<LdReceivedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final eased = LdMotion.curve.transform(_controller.value);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - eased)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LdColors.backgroundElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LdColors.strokeOutline),
        ),
        child: Row(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                LdAvatar(
                  name: widget.senderName,
                  seed: widget.senderSeed,
                  size: 40,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: LdColors.accentPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LdColors.backgroundElevated,
                        width: 2,
                      ),
                    ),
                    child: LdIcon(
                      widget.glyph,
                      size: 11,
                      color: LdColors.foregroundPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.senderName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (widget.onOpen != null && widget.openLabel != null)
              LdButton.text(
                label: widget.openLabel!,
                onPressed: widget.onOpen,
              ),
          ],
        ),
      ),
    );
  }
}
