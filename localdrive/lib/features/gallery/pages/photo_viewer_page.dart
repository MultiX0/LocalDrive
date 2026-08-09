import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../imports.dart';
import '../../files/models/node_model.dart';
import '../../files/providers/files_providers.dart';
import '../../files/widgets/shared/node_actions.dart';
import '../../offline/controller/offline_controller.dart';
import '../../share/widgets/share_sheet.dart';
import '../providers/gallery_providers.dart';

/// One picture, full screen, at full quality.
///
/// The grid shows thumbnails because forty full resolution decodes would take
/// a phone down. This screen is the opposite: one image, fetched at its real
/// size, because the entire reason for opening a photo is to look at it
/// properly.
///
/// Swiping sideways moves through the gallery in the order it was showing,
/// which makes it a gallery rather than a list of files that happen to
/// be pictures.
class PhotoViewerPage extends ConsumerStatefulWidget {
  const PhotoViewerPage({super.key, required this.nodeId});

  final String nodeId;

  @override
  ConsumerState<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends ConsumerState<PhotoViewerPage> {
  PageController? _controller;
  int _index = 0;

  /// the chrome hides on a tap, so the picture can be looked at with nothing
  /// on top of it, and comes back on the next tap
  bool _chrome = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: LdColors.backgroundPrimary,
      body: LdAsync<List<NodeModel>>(
        value: gallery,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(galleryProvider),
        loading: const Center(child: LdSpinner(size: 34)),
        data: (nodes) {
          if (nodes.isEmpty) return const SizedBox.shrink();

          final start = nodes.indexWhere((n) => n.id == widget.nodeId);
          _controller ??= PageController(initialPage: start < 0 ? 0 : start);
          if (_controller!.hasClients == false && start >= 0) _index = start;

          final current = nodes[_index.clamp(0, nodes.length - 1)];

          return Stack(
            children: <Widget>[
              _Pages(
                nodes: nodes,
                controller: _controller!,
                onPageChanged: (index) => setState(() => _index = index),
                onTap: () => setState(() => _chrome = !_chrome),
              ),
              AnimatedOpacity(
                duration: LdMotion.standard,
                curve: LdMotion.curve,
                opacity: _chrome ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_chrome,
                  child: _Chrome(
                    node: current,
                    position: _index + 1,
                    total: nodes.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pages extends ConsumerWidget {
  const _Pages({
    required this.nodes,
    required this.controller,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<NodeModel> nodes;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;

  /// photo_view ignores the mouse wheel, so on a desktop or in a browser an
  /// image otherwise has no way to zoom at all. One controller for the
  /// gallery is enough: the wheel only ever acts on the page in view.
  static final PhotoViewController _zoom = PhotoViewController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(filesDbProvider);

    return ZoomOnScroll(
      controller: _zoom,
      child: PhotoViewGallery.builder(
        itemCount: nodes.length,
        pageController: controller,
        onPageChanged: onPageChanged,
        backgroundDecoration: const BoxDecoration(
          color: LdColors.backgroundPrimary,
        ),
        loadingBuilder: (context, event) =>
            const Center(child: LdSpinner(size: 34)),
        builder: (context, index) {
          final node = nodes[index];
          final local =
              ref.watch(offlineLocalPathProvider(node.id)).valueOrNull ?? '';

          return PhotoViewGalleryPageOptions(
            imageProvider: LdRemoteImage.provider(
              // the full file, not the thumbnail. A gallery that zooms into a
              // 512 pixel preview is not a gallery
              url: db.downloadUrl(node.id, inline: true),
              headers: db.authHeaders,
              localPath: local,
            ),
            heroAttributes: PhotoViewHeroAttributes(tag: 'gallery-${node.id}'),
            controller: _zoom,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 5,
            onTapUp: (context, details, value) => onTap(),
            errorBuilder: (context, error, stack) => LdErrorState(
              kind: LdErrorKind.unexpected,
              title: L10n.of(context).errorUnexpectedTitle,
              message: L10n.of(context).errorUnexpectedBody,
            ),
          );
        },
      ),
    );
  }
}

/// The bar above and the bar below, both of which get out of the way on a tap.
class _Chrome extends ConsumerWidget {
  const _Chrome({
    required this.node,
    required this.position,
    required this.total,
  });

  final NodeModel node;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final offline = ref.watch(isOfflineProvider(node.id));

    return Column(
      children: <Widget>[
        // a gradient rather than a solid bar, so the picture is never cut off
        // by a rectangle of chrome across the top of it
        _Scrim(
          fromTop: true,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  LdUtilityButton(
                    glyph: LdGlyph.chevronLeft,
                    tooltip: l10n.actionBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          l10n.galleryPositionOf(
                            LdFormat.count(context, position),
                            LdFormat.count(context, total),
                          ),
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(color: LdColors.foregroundSecondary),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) => LdUtilityButton(
                      glyph: LdGlyph.more,
                      tooltip: l10n.moreActions,
                      onPressed: () => showNodeActions(
                        context,
                        ref,
                        node,
                        anchorOf(context),
                        alreadyOpen: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        _Scrim(
          fromTop: false,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // when it was taken, which is the one fact anyone actually
                  // wants while looking at a photo
                  Text(
                    node.capturedAt > 0
                        ? LdFormat.dateTime(context, node.capturedAt)
                        : LdFormat.bytes(context, node.sizeBytes),
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: LdColors.foregroundSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _Action(
                        glyph: LdGlyph.shared,
                        label: l10n.actionShare,
                        onTap: () => showShareSheet(context, ref, node),
                      ),
                      _Action(
                        glyph: LdGlyph.download,
                        label: l10n.download,
                        onTap: () =>
                            downloadNodes(context, ref, <NodeModel>[node]),
                      ),
                      if (OfflineController.isSupported)
                        _Action(
                          glyph: LdGlyph.offlineReady,
                          label: offline
                              ? l10n.offlineRemoveDownload
                              : l10n.offlineMakeAvailable,
                          active: offline,
                          onTap: () async {
                            final controller = ref.read(
                              offlineControllerProvider.notifier,
                            );
                            if (offline) {
                              await controller.unmark(node);
                            } else {
                              await controller.mark(node);
                            }
                          },
                        ),
                      _Action(
                        glyph: node.starred ? LdGlyph.starFilled : LdGlyph.star,
                        label: l10n.starred,
                        active: node.starred,
                        onTap: () => toggleStar(context, ref, node),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A gradient behind the chrome, so white text stays readable over a white
/// photo without putting a solid bar across the picture.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.fromTop, required this.child});

  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: <Color>[
            LdColors.backgroundPrimary.withValues(alpha: 0.85),
            LdColors.backgroundPrimary.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.glyph,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final LdGlyph glyph;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? LdColors.accentPrimary : LdColors.foregroundPrimary;

    return LdTappable(
      onTap: onTap,
      borderRadius: LdRadii.tileRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LdIcon(glyph, size: 21, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: active
                    ? LdColors.accentPrimary
                    : LdColors.foregroundSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
