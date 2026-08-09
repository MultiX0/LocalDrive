import '../../../../imports.dart';

/// Every folder tile currently on screen, so a drop from the operating system
/// can land in the folder it was released over.
///
/// One registry rather than a drop target per tile. desktop_drop hit tests its
/// own targets and gives no promise about which of several overlapping ones
/// receives a drop, so nesting a target inside the page wide one risks the same
/// files being uploaded twice, or landing in the wrong folder. Keeping a single
/// target and asking this which folder is under the pointer is exact.
class FolderDropTargets {
  FolderDropTargets._();

  static final FolderDropTargets instance = FolderDropTargets._();

  final Map<String, BuildContext> _folders = <String, BuildContext>{};

  void register(String id, BuildContext context) => _folders[id] = context;

  void unregister(String id) => _folders.remove(id);

  /// The folder whose tile contains [global], or empty for none.
  String at(Offset global) {
    for (final entry in _folders.entries) {
      final box = entry.value.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final origin = box.localToGlobal(Offset.zero);
      if ((origin & box.size).contains(global)) return entry.key;
    }
    return '';
  }
}

/// The folder an operating system drag is currently hovering, so its tile can
/// light up the way an in app drag already does. Empty when the drag is over
/// open space, which means the drop goes to the folder being viewed.
final osDropTargetProvider = StateProvider<String>((ref) => '');

/// Registers one folder tile with the drop registry for as long as it is built.
class FolderDropTarget extends StatefulWidget {
  const FolderDropTarget({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  State<FolderDropTarget> createState() => _FolderDropTargetState();
}

class _FolderDropTargetState extends State<FolderDropTarget> {
  @override
  void initState() {
    super.initState();
    FolderDropTargets.instance.register(widget.id, context);
  }

  @override
  void dispose() {
    FolderDropTargets.instance.unregister(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
