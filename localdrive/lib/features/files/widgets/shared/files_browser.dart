import 'dart:async';

import 'package:flutter/services.dart';

import '../../../offline/controller/offline_controller.dart';
import '../../../../imports.dart';
import '../../controller/files_controller.dart';
import '../../models/node_model.dart';
import '../../providers/files_providers.dart';
import '../desktop/draggable_node.dart';
import '../desktop/marquee_selection.dart';
import 'node_actions.dart';
import 'node_tile.dart';

/// The listing itself, shared by every breakpoint. The page wrappers decide
/// the chrome around it; this decides nothing about layout beyond the column
/// count it is handed.
class FilesBrowser extends ConsumerWidget {
  const FilesBrowser({
    super.key,
    required this.query,
    required this.emptyTitle,
    required this.emptyBody,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.emptyGlyph = LdGlyph.folder,
  });

  final FolderQuery query;
  final String emptyTitle;
  final String emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final LdGlyph emptyGlyph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(folderProvider(query));
    final viewMode = ref.watch(viewModeProvider);
    final selection = ref.watch(selectionProvider);

    return LdRefresh(
      onRefresh: () async {
        ref.invalidate(folderProvider(query));
        await ref.read(folderProvider(query).future);
      },
      child: LdAsync<List<NodeModel>>(
        value: listing,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(folderProvider(query)),
        // the shape of what is coming is known, so a skeleton reads as the
        // content arriving rather than as a wait
        loading: viewMode == ViewMode.grid
            ? LdGridSkeleton(columns: context.gridColumns)
            : const LdListSkeleton(),
        isEmpty: (nodes) => nodes.isEmpty,
        empty: () => LdEmptyState(
          title: emptyTitle,
          message: emptyBody,
          glyph: emptyGlyph,
          actionLabel: emptyActionLabel,
          onAction: onEmptyAction,
        ),
        data: (nodes) {
          final listing = viewMode == ViewMode.grid
              ? _Grid(nodes: nodes, selection: selection, query: query)
              : _List(nodes: nodes, selection: selection, query: query);

          // a rubber band needs a pointer and empty space to start on, so it
          // is a desktop gesture only. A finger dragging on a phone is
          // scrolling, and always will be
          if (!desktopBehaviour(context)) return listing;

          var before = const <String>{};
          // Ctrl+A and Delete, because a file manager that needs the mouse for
          // everything is a file manager nobody trusts with a hundred files.
          return _KeyboardSelection(
            nodes: nodes,
            child: MarqueeSelection(
              onStart: () => before = ref.read(selectionProvider),
              onChanged: (ids, additive) => ref
                  .read(selectionProvider.notifier)
                  .setMarquee(ids, additive: additive, base: before),
              child: listing,
            ),
          );
        },
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({
    required this.nodes,
    required this.selection,
    required this.query,
  });

  final List<NodeModel> nodes;
  final Set<String> selection;
  final FolderQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        8,
        context.pagePadding,
        120,
      ),
      // Sized by how wide a tile should be, not by how many should fit.
      //
      // A fixed column count has to pick a number for every width, so it ends
      // up right at one size and wrong either side: six columns on a wide
      // window made each tile small enough that the icon floated in the middle
      // of mostly empty space. Naming the size instead keeps a tile the same
      // comfortable width everywhere and lets the count fall out of it, which
      // is what every file browser worth copying does.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.86,
      ),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return DraggableNode(
          node: node,
          nodes: nodes,
          child: NodeTile(
            node: node,
            offlineAvailable: ref.watch(isOfflineProvider(node.id)),
            selected: selection.contains(node.id),
            selecting: selection.isNotEmpty,
            // A phone has a selection mode: a long press enters it and every
            // tap after that toggles. A desktop has no such mode, so both
            // paths lead to the same place and the modifiers decide. Without
            // this, selecting one file put the whole grid into toggle mode and
            // a double click could never open anything again.
            onToggleSelect: () => desktopBehaviour(context)
                ? activateNode(context, ref, node, nodes)
                : ref.read(selectionProvider.notifier).toggle(node.id),
            onOpen: () => activateNode(context, ref, node, nodes),
            onMenu: (position) => showNodeActions(context, ref, node, position),
          ),
        );
      },
    );
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.nodes,
    required this.selection,
    required this.query,
  });

  final List<NodeModel> nodes;
  final Set<String> selection;
  final FolderQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding - 8,
        8,
        context.pagePadding - 8,
        120,
      ),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return DraggableNode(
          node: node,
          nodes: nodes,
          child: NodeRow(
            node: node,
            offlineAvailable: ref.watch(isOfflineProvider(node.id)),
            selected: selection.contains(node.id),
            selecting: selection.isNotEmpty,
            // A phone has a selection mode: a long press enters it and every
            // tap after that toggles. A desktop has no such mode, so both
            // paths lead to the same place and the modifiers decide. Without
            // this, selecting one file put the whole grid into toggle mode and
            // a double click could never open anything again.
            onToggleSelect: () => desktopBehaviour(context)
                ? activateNode(context, ref, node, nodes)
                : ref.read(selectionProvider.notifier).toggle(node.id),
            onOpen: () => activateNode(context, ref, node, nodes),
            onMenu: (position) => showNodeActions(context, ref, node, position),
          ),
        );
      },
    );
  }
}

/// What a click does, which is not the same thing on a desktop as on a phone.
///
/// On a phone a tap opens, because there is no second button and no keyboard
/// to qualify it with. On a desktop a click selects and a double click opens,
/// the way Drive and every file manager behave, with ctrl to add one and shift
/// to take a run. Getting this wrong is what makes an app feel like a website
/// rather than something files live in.
void activateNode(
  BuildContext context,
  WidgetRef ref,
  NodeModel node,
  List<NodeModel> ordered,
) {
  if (!desktopBehaviour(context)) {
    openNode(context, ref, node);
    return;
  }

  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  final selection = ref.read(selectionProvider.notifier);

  final toggling =
      keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight);
  if (toggling) {
    selection.toggleAt(node.id);
    return;
  }

  final ranging =
      keys.contains(LogicalKeyboardKey.shiftLeft) ||
      keys.contains(LogicalKeyboardKey.shiftRight);
  if (ranging) {
    selection.selectRange(node.id, <String>[for (final n in ordered) n.id]);
    return;
  }

  if (_DoubleClick.isSecond(node.id)) {
    openNode(context, ref, node);
    return;
  }
  selection.only(node.id);
}

/// Double click, timed by hand rather than with a double tap recogniser.
///
/// Handing a recogniser both gestures makes every single click wait out the
/// double click window before anything happens, so selecting a file would lag
/// by a third of a second for no reason a person could see. Selecting on the
/// first click and opening on the second costs nothing and is what the gesture
/// actually is.
abstract final class _DoubleClick {
  static String _id = '';
  static int _at = 0;

  /// the platform double click time on Windows, and close enough elsewhere
  static const _window = 400;

  static bool isSecond(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final again = _id == id && now - _at < _window;
    _id = id;
    _at = now;
    return again;
  }
}

/// Opening a folder navigates; opening a file goes to the preview screen.
void openNode(BuildContext context, WidgetRef ref, NodeModel node) {
  ref.read(selectionProvider.notifier).clear();
  if (node.isFolder) {
    context.go(Routes.folder(node.id));
    return;
  }
  context.push(Routes.previewOf(node.id));
}

/// The action bar that replaces the toolbar while items are selected.
class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key, required this.nodes});

  final List<NodeModel> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final selection = ref.watch(selectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();

    final chosen = nodes
        .where((node) => selection.contains(node.id))
        .toList(growable: false);
    // an action only offers itself when it applies to every selected item
    final canTrash =
        chosen.isNotEmpty && chosen.every((node) => node.role.canTrash);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.pillRadius,
        border: Border.all(color: LdColors.accentPrimary),
      ),
      child: Row(
        children: <Widget>[
          LdTappable(
            onTap: () => ref.read(selectionProvider.notifier).clear(),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: LdIcon(LdGlyph.close, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.selectedCount(selection.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          LdTappable(
            onTap: () => ref
                .read(selectionProvider.notifier)
                .selectAll(nodes.map((n) => n.id)),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: LdIcon(LdGlyph.check, size: 18),
            ),
          ),
          if (canTrash)
            LdTappable(
              onTap: () async {
                final confirmed = await LdBottomSheet.confirm(
                  context,
                  title: l10n.confirmTrashTitle,
                  message: l10n.confirmTrashBody(
                    l10n.selectedCount(chosen.length),
                  ),
                  confirmLabel: l10n.actionDelete,
                  cancelLabel: l10n.actionCancel,
                  destructive: true,
                );
                if (!confirmed || !context.mounted) return;
                await ref
                    .read(filesControllerProvider.notifier)
                    .trashMany(chosen);
                ref.read(selectionProvider.notifier).clear();
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: LdIcon(
                  LdGlyph.trash,
                  size: 18,
                  color: LdColors.accentWarning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The keyboard half of desktop selection.
///
/// Ctrl+A takes everything shown, Escape drops the selection, and Delete sends
/// it to the trash after the same confirmation the button uses. Nothing here is
/// destructive without asking: a stray Delete on a full selection would be the
/// worst possible thing to make silent.
class _KeyboardSelection extends ConsumerWidget {
  const _KeyboardSelection({required this.nodes, required this.child});

  final List<NodeModel> nodes;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            const _SelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            const _SelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _ClearIntent(),
        const SingleActivator(LogicalKeyboardKey.delete): const _TrashIntent(),
        const SingleActivator(LogicalKeyboardKey.backspace):
            const _TrashIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SelectAllIntent: CallbackAction<_SelectAllIntent>(
            onInvoke: (_) {
              ref
                  .read(selectionProvider.notifier)
                  .selectAll(nodes.map((n) => n.id));
              return null;
            },
          ),
          _ClearIntent: CallbackAction<_ClearIntent>(
            onInvoke: (_) {
              ref.read(selectionProvider.notifier).clear();
              return null;
            },
          ),
          _TrashIntent: CallbackAction<_TrashIntent>(
            onInvoke: (_) {
              unawaited(_trashSelected(context, ref));
              return null;
            },
          ),
        },
        // the grid has to hold focus for any of this to arrive, and it should
        // hold it from the moment the screen opens rather than after a click
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  Future<void> _trashSelected(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final selection = ref.read(selectionProvider);
    final chosen = nodes
        .where((node) => selection.contains(node.id) && node.role.canTrash)
        .toList(growable: false);
    if (chosen.isEmpty) return;

    final confirmed = await LdBottomSheet.confirm(
      context,
      title: l10n.confirmTrashTitle,
      message: l10n.confirmTrashBody(l10n.selectedCount(chosen.length)),
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(filesControllerProvider.notifier).trashMany(chosen);
    ref.read(selectionProvider.notifier).clear();
  }
}

class _SelectAllIntent extends Intent {
  const _SelectAllIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}

class _TrashIntent extends Intent {
  const _TrashIntent();
}
