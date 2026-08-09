import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../core/router/deep_links.dart';
import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';
import '../../upload/controller/transfer_controller.dart';

/// Everything that arrives from outside the app: a link, and a share.
///
/// Both are handled here rather than in the router, because both can need a
/// decision first. A link may belong to a different server than the one this
/// device is signed in to, and a share needs somewhere to put the files.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<String>? _links;
  StreamSubscription<List<SharedMediaFile>>? _shares;

  @override
  void initState() {
    super.initState();
    // deferred to after the first frame: both of these can navigate, and the
    // router is not mounted while initState runs
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    if (!mounted) return;

    _links = ref
        .read(platformServiceProvider)
        .deepLinks
        .listen((link) => unawaited(_openLink(link)));

    if (kIsWeb) return;

    // a share that arrived while the app was already running
    _shares = ReceiveSharingIntent.instance.getMediaStream().listen(
          (files) => unawaited(_receive(files)),
          onError: (Object _) {
            // an unreadable share is not worth surfacing; nothing was lost
            // that the sending app cannot send again
          },
        );

    // and one that started the app cold
    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then((files) async {
        if (files.isEmpty) return;
        await _receive(files);
        // tells the plugin the cold start share is consumed, so it is not
        // delivered a second time on the next resume
        ReceiveSharingIntent.instance.reset();
      }),
    );
  }

  /// Opens a link, after checking it belongs to the server this device is
  /// actually signed in to.
  Future<void> _openLink(String raw) async {
    final link = parseDeepLink(raw);
    if (link == null || !mounted) return;

    final session = ref.read(sessionProvider);

    // a public share link works with no session at all, so it never prompts
    final isPublic = link.path.startsWith('/s/');

    if (!isPublic &&
        link.namesServer &&
        !linkMatchesNode(link.serverUrl, session.nodeUrl)) {
      final l10n = L10n.of(context);
      final switchNode = await LdBottomSheet.confirm(
        context,
        title: l10n.deepLinkOtherServerTitle,
        message: l10n.deepLinkOtherServerBody(link.serverUrl),
        confirmLabel: l10n.settingsSwitchNode,
        cancelLabel: l10n.actionCancel,
      );
      if (!switchNode || !mounted) return;
      await ref.read(sessionProvider.notifier).switchNode();
      return;
    }

    if (!mounted) return;
    context.go(link.path);
  }

  /// Turns files handed over by the system share sheet into real uploads.
  ///
  /// They land in whatever folder is open, which is what someone sharing into
  /// a file app expects, and go through the same durable queue as everything
  /// else so closing the app straight after does not lose them.
  Future<void> _receive(List<SharedMediaFile> files) async {
    final paths = files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty)
        .toList();
    if (paths.isEmpty || !mounted) return;

    // the folder currently open, so a share lands where someone is looking
    // rather than always at the root
    final location = currentLocation(context);
    final parentId = Routes.folderIdIn(location) ?? '';

    await ref.read(transferControllerProvider.notifier).enqueueUploads(
          paths: paths,
          parentId: parentId,
        );

    if (!mounted) return;
    final l10n = L10n.of(context);
    LdToast.success(
      context,
      paths.length == 1
          ? l10n.shareReceivedOne
          : l10n.shareReceivedMany(paths.length),
    );
    context.go(Routes.transfers);
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    unawaited(_shares?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
