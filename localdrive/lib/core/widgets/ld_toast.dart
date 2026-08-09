import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import '../constants/ld_radii.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// What a toast is telling the person.
enum LdToastKind { info, success, warning, error }

/// The branded snackbar equivalent. Never a SnackBar.
///
/// Because it renders through an Overlay, outside the page's own widget tree,
/// its content is wrapped in `Material(type: MaterialType.transparency)`. Skip
/// that and text and icons inside throw "No Material widget found" and ink
/// effects fail to clip. This is a common miss, so it is done here once and
/// never left to a caller.
class LdToast {
  LdToast._();

  static final Queue<_ToastRequest> _queue = Queue<_ToastRequest>();
  static OverlayEntry? _entry;
  static Timer? _timer;

  /// Shows a toast, queued behind any that are already visible so two never
  /// overlap.
  static void show(
    BuildContext context, {
    required String message,
    LdToastKind kind = LdToastKind.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = LdMotion.toastVisible,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _queue.add(_ToastRequest(
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      overlay: overlay,
    ));
    if (_entry == null) _pump();
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, kind: LdToastKind.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, kind: LdToastKind.error);

  static void _pump() {
    if (_queue.isEmpty) {
      _entry = null;
      return;
    }
    final request = _queue.removeFirst();
    final controllerKey = GlobalKey<_LdToastCardState>();

    final entry = OverlayEntry(
      builder: (context) => _LdToastCard(
        key: controllerKey,
        request: request,
        onDismissed: _next,
      ),
    );
    _entry = entry;
    request.overlay.insert(entry);

    _timer?.cancel();
    _timer = Timer(request.duration, () {
      controllerKey.currentState?.dismiss();
    });
  }

  static void _next() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    _pump();
  }

  /// Clears anything queued, used when the app navigates away from a node.
  static void clear() {
    _timer?.cancel();
    _queue.clear();
    _entry?.remove();
    _entry = null;
  }
}

class _ToastRequest {
  const _ToastRequest({
    required this.message,
    required this.kind,
    required this.duration,
    required this.overlay,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final LdToastKind kind;
  final Duration duration;
  final OverlayState overlay;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class _LdToastCard extends StatefulWidget {
  const _LdToastCard({super.key, required this.request, required this.onDismissed});

  final _ToastRequest request;
  final VoidCallback onDismissed;

  @override
  State<_LdToastCard> createState() => _LdToastCardState();
}

class _LdToastCardState extends State<_LdToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LdMotion.toast,
  )..forward();

  Future<void> dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final curved = CurvedAnimation(parent: _controller, curve: LdMotion.curve);
    final accent = switch (widget.request.kind) {
      LdToastKind.success => LdColors.fileSpreadsheet,
      LdToastKind.warning => LdColors.filePresentation,
      LdToastKind.error => LdColors.accentWarning,
      LdToastKind.info => LdColors.accentPrimary,
    };
    final glyph = switch (widget.request.kind) {
      LdToastKind.success => LdGlyph.check,
      LdToastKind.warning => LdGlyph.warning,
      LdToastKind.error => LdGlyph.warning,
      LdToastKind.info => LdGlyph.info,
    };

    return Positioned(
      left: 0,
      right: 0,
      bottom: media.padding.bottom + 24,
      child: IgnorePointer(
        ignoring: _controller.status == AnimationStatus.reverse,
        // the overlay sits outside the page tree, so the toast brings its own
        // Material ancestor
        child: Material(
          type: MaterialType.transparency,
          child: FadeTransition(
            opacity: curved,
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, 20 * (1 - curved.value)),
                child: child,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: LdColors.backgroundElevated,
                        borderRadius: LdRadii.cardRadius,
                        border: Border.all(color: LdColors.strokeOutline),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          LdIcon(glyph, size: 20, color: accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.request.message,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (widget.request.actionLabel != null) ...<Widget>[
                            const SizedBox(width: 8),
                            LdTappable(
                              onTap: () {
                                widget.request.onAction?.call();
                                dismiss();
                              },
                              borderRadius: LdRadii.chipRadius,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  widget.request.actionLabel!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge!
                                      .copyWith(color: LdColors.accentPrimary),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
