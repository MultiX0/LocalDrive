import '../../../../imports.dart';
import '../../models/node_model.dart';
import '../../providers/files_providers.dart';

/// One item in the grid. Each corner is reserved for one thing: owner avatar
/// top left when it is not yours, offline badge top right, file type badge
/// bottom right. Bottom left stays open.
class NodeTile extends HookConsumerWidget {
  const NodeTile({
    super.key,
    required this.node,
    required this.onOpen,
    this.onMenu,
    this.selected = false,
    this.selecting = false,
    this.onToggleSelect,
    this.offlineAvailable = false,
  });

  final NodeModel node;
  final VoidCallback onOpen;
  final void Function(Offset position)? onMenu;
  final bool selected;
  final bool selecting;
  final VoidCallback? onToggleSelect;
  final bool offlineAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hovered = useState(false);
    final db = ref.watch(filesDbProvider);
    final deviceClass = context.deviceClass;

    // a folder's peek only loads when there is a pointer to hover with, or on
    // mobile where it sits open; it is never fetched for a plain file
    final peek = node.isFolder
        ? ref.watch(folderPreviewProvider(node.id))
        : const AsyncValue<List<NodePreviewModel>>.data(
            <NodePreviewModel>[],
          );

    final peekImages = peek.maybeWhen(
      data: (previews) => previews
          .map<ImageProvider>(
            (p) => LdRemoteImage.provider(
              url: db.thumbnailUrl(p.nodeId),
              headers: db.authHeaders,
            ),
          )
          .toList(growable: false),
      orElse: () => const <ImageProvider>[],
    );

    return Semantics(
      label: node.name,
      selected: selected,
      button: true,
      child: LdTappable(
        onTap: selecting ? onToggleSelect : onOpen,
        onLongPress: onToggleSelect,
        onSecondaryTap: onMenu,
        onHoverChanged: (value) => hovered.value = value,
        borderRadius: LdRadii.tileRadius,
        child: AnimatedContainer(
          duration: LdMotion.tapFade,
          decoration: BoxDecoration(
            borderRadius: LdRadii.tileRadius,
            border: Border.all(
              color: selected ? LdColors.accentPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      LdFileTile(
                        category: node.category,
                        hasThumbnail: node.hasThumbnail,
                        thumbnail: node.hasThumbnail
                            ? LdRemoteImage.provider(
                                url: db.thumbnailUrl(node.id),
                                headers: db.authHeaders,
                              )
                            : null,
                        folderColor: node.color,
                        peekThumbnails: peekImages,
                        hovered: hovered.value,
                        alwaysPeek: !deviceClass.hasHover,
                      ),
                      if (node.owner != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: LdAvatar(
                            name: node.owner!.name,
                            seed: node.owner!.avatarSeed,
                            size: 26,
                            showBorder: true,
                          ),
                        ),
                      // top-right is the fourth and last corner: the type
                      // badge holds bottom-right and the owner avatar
                      // top-left, and bottom-left is left alone rather than
                      // crowding all four for the sake of it
                      if (offlineAvailable && !selecting)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: _OfflineBadge(),
                        ),
                      if (selecting)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _SelectionDot(selected: selected),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _TileCaption(node: node),
            ],
          ),
        ),
      ),
    );
  }
}

/// The offline available mark: a filled circle with a checkmark, small enough
/// to sit in a tile corner without competing with the thumbnail behind it.
class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LdColors.accentPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: LdColors.backgroundPrimary, width: 1.5),
      ),
      child: const LdIcon(
        LdGlyph.check,
        size: 11,
        color: LdColors.foregroundPrimary,
        strokeWidth: 2.4,
      ),
    );
  }
}

class _TileCaption extends StatelessWidget {
  const _TileCaption({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: LdColors.foregroundPrimary,
                    ),
              ),
            ),
            if (node.starred)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: LdIcon(
                  LdGlyph.starFilled,
                  size: 13,
                  color: LdColors.filePresentation,
                ),
              ),
            if (node.hasActiveShare)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: LdIcon(
                  LdGlyph.link,
                  size: 13,
                  color: LdColors.accentPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          node.isFolder
              ? LdFormat.relative(context, node.updatedAt)
              : LdFormat.bytes(context, node.sizeBytes),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// One item in the list view.
class NodeRow extends ConsumerWidget {
  const NodeRow({
    super.key,
    required this.node,
    required this.onOpen,
    this.onMenu,
    this.selected = false,
    this.selecting = false,
    this.onToggleSelect,
    this.offlineAvailable = false,
    this.trailing,
  });

  final NodeModel node;
  final VoidCallback onOpen;
  final void Function(Offset position)? onMenu;
  final bool selected;
  final bool selecting;
  final VoidCallback? onToggleSelect;
  final bool offlineAvailable;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(filesDbProvider);

    return Semantics(
      label: node.name,
      selected: selected,
      button: true,
      child: LdTappable(
        onTap: selecting ? onToggleSelect : onOpen,
        onLongPress: onToggleSelect,
        onSecondaryTap: onMenu,
        borderRadius: LdRadii.tileRadius,
        child: AnimatedContainer(
          duration: LdMotion.tapFade,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? LdColors.wash(LdColors.accentPrimary, 0.1)
                : Colors.transparent,
            borderRadius: LdRadii.tileRadius,
          ),
          child: Row(
            children: <Widget>[
              if (selecting) ...<Widget>[
                _SelectionDot(selected: selected),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  children: <Widget>[
                    // the type icon is the base layer, so a row with no
                    // thumbnail, and a row whose thumbnail is still arriving,
                    // both show the right kind of thing rather than a hole
                    LdFileIcon(
                      category: node.category,
                      size: 42,
                      folderColor: node.color,
                    ),
                    if (node.hasThumbnail)
                      LdRemoteImage(
                        url: db.thumbnailUrl(node.id),
                        headers: db.authHeaders,
                        width: 42,
                        height: 42,
                        // decoded no larger than the row draws it
                        memCacheWidth: 96,
                        tint: node.category.tint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    if (node.owner != null)
                      Positioned(
                        top: -2,
                        left: -2,
                        child: LdAvatar(
                          name: node.owner!.name,
                          seed: node.owner!.avatarSeed,
                          size: 18,
                          showBorder: true,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (node.starred)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: LdIcon(
                              LdGlyph.starFilled,
                              size: 13,
                              color: LdColors.filePresentation,
                            ),
                          ),
                        if (node.hasActiveShare)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: LdIcon(
                              LdGlyph.link,
                              size: 13,
                              color: LdColors.accentPrimary,
                            ),
                          ),
                        if (offlineAvailable)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: LdIcon(
                              LdGlyph.offlineReady,
                              size: 13,
                              color: LdColors.accentPrimary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (onMenu != null && !selecting)
                Builder(
                  builder: (context) => LdTappable(
                    onTap: () {
                      final box = context.findRenderObject() as RenderBox?;
                      final origin =
                          box?.localToGlobal(Offset.zero) ?? Offset.zero;
                      onMenu!(origin);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: LdIcon(
                        LdGlyph.more,
                        size: 18,
                        color: LdColors.foregroundSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(BuildContext context) {
    // joined with a middot, not a space. Two facts run together as
    // "300 KB 2 hours ago" and read as one broken phrase; the separator is
    // what tells the eye where one ends and the next begins.
    final when = LdFormat.relative(context, node.updatedAt);
    if (node.isFolder) {
      return node.owner != null ? _join(node.owner!.name, when) : when;
    }
    final size = LdFormat.bytes(context, node.sizeBytes);
    return node.owner != null
        ? _join(node.owner!.name, size)
        : _join(size, when);
  }

  static String _join(String a, String b) => '$a  ·  $b';
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: LdMotion.tapFade,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? LdColors.accentPrimary : const Color(0x99141414),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? LdColors.accentPrimary : LdColors.foregroundPrimary,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Center(
              child: LdIcon(
                LdGlyph.check,
                size: 14,
                color: LdColors.foregroundPrimary,
                strokeWidth: 2.6,
              ),
            )
          : null,
    );
  }
}
