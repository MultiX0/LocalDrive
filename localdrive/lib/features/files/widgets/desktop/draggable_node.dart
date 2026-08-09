import '../../../../imports.dart';
import '../../controller/files_controller.dart';
import '../../models/node_model.dart';
import '../../providers/files_providers.dart';
import 'folder_drop_targets.dart';
import 'marquee_selection.dart';

/// What a drag carries: the nodes being moved.
///
/// Dragging one of several selected items moves the whole selection, which is
/// what every file manager does and what anyone who has just selected six
/// photos expects. Dragging something outside the selection moves only that,
/// and does not quietly drag the six along with it.
class NodeDrag {
  const NodeDrag(this.nodes);

  final List<NodeModel> nodes;
}

/// Makes a tile draggable, a folder tile a drop target, and registers it with
/// the marquee, all in one wrapper so the grid and the list stay readable.
///
/// Everything here is desktop only. A phone has no pointer to drag with and a
/// long press already means select, so hanging a drag off it would take the
/// gesture away from the thing that uses it.
class DraggableNode extends ConsumerWidget {
  const DraggableNode({
    super.key,
    required this.node,
    required this.nodes,
    required this.child,
  });

  final NodeModel node;
  final List<NodeModel> nodes;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!desktopBehaviour(context)) return child;

    final registered = MarqueeItem(id: node.id, child: child);
    final draggable = node.role.canMove
        ? Draggable<NodeDrag>(
            data: NodeDrag(_moving(ref)),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _Badge(count: _moving(ref).length, name: node.name),
            // the tile stays put and dims, rather than leaving a hole in the
            // grid that everything after it slides into mid drag
            childWhenDragging: Opacity(opacity: 0.35, child: registered),
            child: registered,
          )
        : registered;

    if (!node.isFolder) return draggable;
    // a folder is a target twice over: for nodes dragged inside the app, and
    // for files dragged in from the desktop
    return FolderDropTarget(
      id: node.id,
      child: _FolderTarget(node: node, child: draggable),
    );
  }

  /// The selection when this tile is part of it, otherwise just this tile.
  List<NodeModel> _moving(WidgetRef ref) {
    final selection = ref.read(selectionProvider);
    if (!selection.contains(node.id)) return <NodeModel>[node];
    return <NodeModel>[
      for (final n in nodes)
        if (selection.contains(n.id)) n,
    ];
  }
}

/// A folder that accepts a drop.
class _FolderTarget extends ConsumerStatefulWidget {
  const _FolderTarget({required this.node, required this.child});

  final NodeModel node;
  final Widget child;

  @override
  ConsumerState<_FolderTarget> createState() => _FolderTargetState();
}

class _FolderTargetState extends ConsumerState<_FolderTarget> {
  @override
  Widget build(BuildContext context) {
    return DragTarget<NodeDrag>(
      onWillAcceptWithDetails: (details) => _accepts(details.data),
      onAcceptWithDetails: (details) async {
        final l10n = L10n.of(context);
        final moving = details.data.nodes;
        await ref
            .read(filesControllerProvider.notifier)
            .moveMany(moving, widget.node.id);
        ref.read(selectionProvider.notifier).clear();
        if (context.mounted) LdToast.success(context, l10n.actionMove);
      },
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty ||
            ref.watch(osDropTargetProvider) == widget.node.id;
        return AnimatedContainer(
          duration: LdMotion.tapFade,
          decoration: BoxDecoration(
            borderRadius: LdRadii.tileRadius,
            color: active
                ? LdColors.wash(LdColors.accentPrimary, 0.12)
                : Colors.transparent,
            border: Border.all(
              color: active ? LdColors.accentPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }

  /// A folder cannot take itself, and cannot take something already in it.
  ///
  /// The question a target has to answer is whether things can be added to it,
  /// which is canCreate. It is not canMove: that asks whether this folder can
  /// itself be moved somewhere else, which has nothing to do with dropping
  /// into it and would refuse every folder a person only shares.
  ///
  /// The server refuses an impossible move anyway, but a target that lights up
  /// and then fails is worse than one that never lights up: it says the move
  /// was possible right up until it was not.
  bool _accepts(NodeDrag drag) {
    if (!widget.node.role.canCreate) return false;
    for (final node in drag.nodes) {
      if (node.id == widget.node.id) return false;
      if (node.parentId == widget.node.id) return false;
      if (!node.role.canMove) return false;
    }
    return true;
  }
}

/// What follows the pointer during a drag.
class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.name});

  final int count;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: LdColors.backgroundElevated,
          borderRadius: LdRadii.pillRadius,
          border: Border.all(color: LdColors.accentPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LdIcon(
              LdGlyph.move,
              size: 17,
              color: LdColors.accentPrimary,
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                count == 1 ? name : l10n.selectedCount(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
