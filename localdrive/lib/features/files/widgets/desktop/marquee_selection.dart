import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../../imports.dart';

/// Rubber band selection: drag on empty space and everything the box touches
/// becomes selected.
///
/// Every desktop file manager does this and there is no substitute for it. The
/// alternative is clicking twelve photos one at a time, which is the kind of
/// thing that makes a file app feel like a website.
///
/// It only listens to a primary drag that starts on empty space. A drag that
/// starts on a tile belongs to that tile, which is how a tile can be dragged
/// into a folder without the two gestures fighting each other.
class MarqueeSelection extends StatefulWidget {
  const MarqueeSelection({
    super.key,
    required this.child,
    required this.onChanged,
    required this.onStart,
    this.enabled = true,
  });

  final Widget child;

  /// the ids the box currently covers, sent on every move so the tiles light
  /// up as the box passes over them rather than only at the end
  final void Function(Set<String> ids, bool additive) onChanged;

  /// fired once when a drag begins, so the caller can remember what was
  /// selected before it started
  final VoidCallback onStart;

  final bool enabled;

  @override
  State<MarqueeSelection> createState() => _MarqueeSelectionState();

  /// Registers a tile's rectangle with the nearest marquee above it.
  static MarqueeRegistry? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_MarqueeScope>()
      ?.registry;
}

/// Where the tiles report themselves.
///
/// Positions are read from the render tree on demand rather than stored on
/// every scroll frame: a list of a thousand files would otherwise spend its
/// time bookkeeping rectangles nobody is looking at.
class MarqueeRegistry {
  final Map<String, BuildContext> _items = <String, BuildContext>{};

  void register(String id, BuildContext context) => _items[id] = context;

  void unregister(String id) => _items.remove(id);

  /// Every registered id whose box overlaps [rect], in global coordinates.
  Set<String> hits(Rect rect) {
    final found = <String>{};
    for (final entry in _items.entries) {
      final box = entry.value.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final origin = box.localToGlobal(Offset.zero);
      if (rect.overlaps(origin & box.size)) found.add(entry.key);
    }
    return found;
  }
}

class _MarqueeScope extends InheritedWidget {
  const _MarqueeScope({required this.registry, required super.child});

  final MarqueeRegistry registry;

  @override
  bool updateShouldNotify(_MarqueeScope oldWidget) =>
      oldWidget.registry != registry;
}

class _MarqueeSelectionState extends State<MarqueeSelection> {
  final MarqueeRegistry _registry = MarqueeRegistry();

  Offset? _from;
  Offset? _to;
  bool _additive = false;

  Rect? get _rect =>
      _from == null || _to == null ? null : Rect.fromPoints(_from!, _to!);

  bool get _modifierHeld {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  void _start(Offset global) {
    _additive = _modifierHeld;
    widget.onStart();
    setState(() {
      _from = global;
      _to = global;
    });
  }

  void _update(Offset global) {
    setState(() => _to = global);
    final rect = _rect;
    if (rect != null) widget.onChanged(_registry.hits(rect), _additive);
  }

  void _end() => setState(() {
        _from = null;
        _to = null;
      });

  /// Whether a point is over empty space rather than a tile.
  ///
  /// This is what decides a marquee from a drag: pressing on a tile means that
  /// tile is being moved, pressing on the space between them means a box is
  /// being drawn. Asking the registry is exact, where guessing from the grid
  /// geometry would be wrong the moment a row is a different height.
  bool _onEmptySpace(Offset global) =>
      _registry.hits(Rect.fromCenter(center: global, width: 2, height: 2))
          .isEmpty;

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons != kPrimaryMouseButton) return;
    if (!_onEmptySpace(event.position)) return;
    _start(event.position);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return _MarqueeScope(registry: _registry, child: widget.child);
    }

    // A raw Listener rather than a gesture recogniser. The grid inside is a
    // Scrollable, and a scrollable wins any drag it competes for, so a pan
    // recogniser wrapped around it would never see a single move. A listener
    // sits outside the arena entirely and gets the events regardless.
    //
    // The other half of that is suspending the scroll while the band is up,
    // or the tiles would slide under the box being drawn over them.
    return _MarqueeScope(
      registry: _registry,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: (event) {
          if (_from != null) _update(event.position);
        },
        onPointerUp: (_) {
          if (_from != null) _end();
        },
        onPointerCancel: (_) {
          if (_from != null) _end();
        },
        child: Stack(
          children: <Widget>[
            ScrollConfiguration(
              behavior: _MarqueeScrollBehavior(frozen: _from != null),
              child: widget.child,
            ),
            if (_rect != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BandPainter(_rect!, context)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Holds the listing still while a band is being drawn over it.
class _MarqueeScrollBehavior extends MaterialScrollBehavior {
  const _MarqueeScrollBehavior({required this.frozen});

  final bool frozen;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => frozen
      ? const NeverScrollableScrollPhysics()
      : super.getScrollPhysics(context);
}

/// The band itself: a wash of the accent with a one pixel edge, the same way
/// every other surface in the app is drawn.
class _BandPainter extends CustomPainter {
  _BandPainter(this.globalRect, this.context);

  final Rect globalRect;
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = Rect.fromPoints(
      box.globalToLocal(globalRect.topLeft),
      box.globalToLocal(globalRect.bottomRight),
    );

    canvas
      ..drawRect(
        rect,
        Paint()..color = LdColors.wash(LdColors.accentPrimary, 0.14),
      )
      ..drawRect(
        rect,
        Paint()
          ..color = LdColors.accentPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) =>
      oldDelegate.globalRect != globalRect;
}

/// Wraps one tile so a marquee can find it.
class MarqueeItem extends StatefulWidget {
  const MarqueeItem({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  State<MarqueeItem> createState() => _MarqueeItemState();
}

class _MarqueeItemState extends State<MarqueeItem> {
  MarqueeRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final found = MarqueeSelection.of(context);
    if (found == _registry) return;
    _registry?.unregister(widget.id);
    _registry = found?..register(widget.id, context);
  }

  @override
  void dispose() {
    _registry?.unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
