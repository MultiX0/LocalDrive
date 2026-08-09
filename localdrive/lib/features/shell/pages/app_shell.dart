import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';
import '../../files/widgets/shared/rename_sheet.dart';
import '../../storage/providers/storage_providers.dart';
import '../../upload/controller/transfer_controller.dart';
import '../../about/controller/update_controller.dart';
import '../widgets/uploads_tray.dart';

/// Whether the phone tab bar belongs on this screen at all.
///
/// Stated as what the tabs are, not as a list of exceptions. The exception
/// list kept missing screens, and every one it missed showed a bar with Home
/// lit while standing somewhere else, which is the bar telling you a lie about
/// where you are. Anything not on this list is opened from inside another
/// screen and carries its own back control.
bool isTabDestination(String location) =>
    location == Routes.files ||
    location.startsWith('${Routes.files}/') ||
    location.startsWith(Routes.gallery) ||
    location.startsWith(Routes.shared) ||
    location.startsWith(Routes.settings);

/// The navigation chrome every main screen sits inside: a floating pill bar on
/// mobile, the same destinations as a persistent sidebar on desktop.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LdResponsive(
      mobile: (context) => _MobileShell(child: child),
      tablet: (context) => _MobileShell(child: child),
      desktop: (context) => _DesktopShell(child: child),
    );
  }
}

/// The banner strip: an offline drive says so once, at the top, instead of
/// every file in it failing separately.
class _Banners extends ConsumerWidget {
  const _Banners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final offline = ref.watch(offlineLibrariesProvider);
    final connection = ref.watch(connectionStateProvider);
    final summary = ref.watch(transferSummaryProvider);

    final disconnected = connection.maybeWhen(
      data: (value) => value == LdConnectionState.disconnected,
      orElse: () => false,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (disconnected)
          LdBanner(
            message: l10n.errorOfflineTitle,
            glyph: LdGlyph.offline,
            tint: LdColors.foregroundSecondary,
          ),
        for (final library in offline)
          LdBanner(
            message: l10n.storageOfflineBanner(library.name),
            glyph: LdGlyph.drive,
          ),
        if (summary.paused)
          LdBanner(
            message: l10n.transferPausedOffline,
            glyph: LdGlyph.upload,
            tint: LdColors.accentPrimary,
          ),
        const _UpdateBanner(),
      ],
    );
  }
}

/// Says once, quietly, that there is a newer version.
///
/// The check runs by itself on launch because nobody goes looking for a
/// version number, and a fix nobody installs is a fix that did not happen.
/// Nothing downloads from here: this is a sentence and a way to go read what
/// changed, and the decision stays with whoever is using the app.
class _UpdateBanner extends ConsumerStatefulWidget {
  const _UpdateBanner();

  @override
  ConsumerState<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<_UpdateBanner> {
  @override
  void initState() {
    super.initState();
    // quiet, so a laptop with no connection does not open onto an error about
    // GitHub when all anyone did was start the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(updateControllerProvider.notifier).check(quiet: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateControllerProvider);
    if (state is! UpdateAvailable) return const SizedBox.shrink();

    final l10n = L10n.of(context);
    return LdBanner(
      message: l10n.updateAvailable(state.release.version),
      glyph: LdGlyph.download,
      tint: LdColors.accentPrimary,
      action: LdTappable(
        onTap: () => context.push(Routes.settingsAbout),
        borderRadius: LdRadii.chipRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            l10n.updateNotes,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: LdColors.accentPrimary,
                ),
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends ConsumerWidget {
  const _MobileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final location = currentLocation(context);
    final index = _mobileIndexOf(location);

    return Scaffold(
      backgroundColor: LdColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _Banners(),
            Expanded(
              child: Stack(
                children: <Widget>[
                  child,
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: UploadsTray(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // A tab bar belongs to the tabs. Storage and Trash are opened from
      // inside Settings, so showing it there left every tab unlit except
      // Home, which was highlighted while standing on neither: the bar was
      // saying you were somewhere you were not. These screens carry their own
      // back control instead.
      bottomNavigationBar: !isTabDestination(location)
          ? null
          : LdBottomNav(
        currentIndex: index,
        onSelected: (next) => _onDestination(context, ref, next),
        items: <LdNavItem>[
          LdNavItem(glyph: LdGlyph.home, label: l10n.navHome),
          LdNavItem(glyph: LdGlyph.image, label: l10n.gallery),
          LdNavItem(
            glyph: LdGlyph.plus,
            label: l10n.navCreate,
            emphasized: true,
          ),
          LdNavItem(glyph: LdGlyph.shared, label: l10n.navShared),
          LdNavItem(glyph: LdGlyph.settings, label: l10n.navSettings),
        ],
      ),
    );
  }

  static int _mobileIndexOf(String location) {
    if (location.startsWith(Routes.gallery)) return 1;
    if (location.startsWith(Routes.shared)) return 3;
    if (location.startsWith(Routes.settings)) return 4;
    return 0;
  }


  void _onDestination(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        context.go(Routes.files);
      case 1:
        context.go(Routes.gallery);
      case 2:
        // create does not navigate; it opens the same sheet from anywhere
        unawaitedCreate(context, ref);
      case 3:
        context.go(Routes.shared);
      case 4:
        context.go(Routes.settings);
    }
  }
}

class _DesktopShell extends ConsumerWidget {
  const _DesktopShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final location = currentLocation(context);
    final session = ref.watch(sessionProvider);

    final destinations = <({String route, LdNavItem item})>[
      (
        route: Routes.files,
        item: LdNavItem(glyph: LdGlyph.home, label: l10n.myFiles),
      ),
      (
        route: Routes.gallery,
        item: LdNavItem(glyph: LdGlyph.image, label: l10n.gallery),
      ),
      (
        route: Routes.shared,
        item: LdNavItem(glyph: LdGlyph.shared, label: l10n.sharedWithMe),
      ),
      (
        route: Routes.recent,
        item: LdNavItem(glyph: LdGlyph.clock, label: l10n.recent),
      ),
      (
        route: Routes.starred,
        item: LdNavItem(glyph: LdGlyph.star, label: l10n.starred),
      ),
      (
        route: Routes.trash,
        item: LdNavItem(glyph: LdGlyph.trash, label: l10n.trash),
      ),
      (
        route: Routes.storage,
        item: LdNavItem(glyph: LdGlyph.drive, label: l10n.storage),
      ),
      (
        route: Routes.settings,
        item: LdNavItem(glyph: LdGlyph.settings, label: l10n.settings),
      ),
    ];

    var current = 0;
    for (var i = destinations.length - 1; i >= 0; i--) {
      if (location.startsWith(destinations[i].route)) {
        current = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: LdColors.backgroundPrimary,
      body: Column(
        children: <Widget>[
          // Minimise, maximise and close, drawn in the brand rather than the
          // system's. Every other desktop screen already had this through
          // LdDesktopScaffold; the main shell builds its own Scaffold and so
          // came up with no window controls and its header against the corner.
          const LdWindowBar(),
          Expanded(
            child: Row(
              children: <Widget>[
                LdSidebar(
                  currentIndex: current,
                  onSelected: (index) => context.go(destinations[index].route),
                  items: destinations
                      .map((d) => d.item)
                      .toList(growable: false),
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LdWordmark(
                        title: session.serverName.isEmpty
                            ? l10n.appName
                            : session.serverName,
                      ),
                      const SizedBox(height: 18),
                      Builder(
                        builder: (context) => LdButton(
                          label: l10n.upload,
                          glyph: LdGlyph.upload,
                          compact: true,
                          onPressed: () => unawaitedCreate(
                            context,
                            ref,
                            anchor: anchorOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  footer: const _QuotaFooter(),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      const _Banners(),
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            child,
                            const Positioned(
                              right: 20,
                              bottom: 20,
                              width: 360,
                              child: UploadsTray(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The quota bar under the sidebar: what this account is using, and what is
/// left to use. The two halves come from different places:
///
/// **Used** is this account's own files. Everyone on the server sees their own
/// number, and one person filling the disk never makes another person's usage
/// go up.
///
/// **Free** is the disk, which everyone shares. It moves when anybody uploads,
/// so two people looking at the same moment see the same free figure beside
/// different used figures.
///
/// The bar measures whichever limit binds first. A 100 GB quota is not 100 GB
/// of headroom when the disk has 2 GB left, so the remaining space is the
/// smaller of the two, and the bar is drawn against used plus that.
class _QuotaFooter extends ConsumerWidget {
  const _QuotaFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final libraries = ref.watch(librariesProvider);
    final diskFree = libraries.maybeWhen(
      data: (summary) => summary.totalFree,
      orElse: () => -1,
    );

    // nothing useful to say until at least one of the two numbers is known
    if (diskFree < 0 && !user.hasQuota) return const SizedBox.shrink();

    final used = user.quotaBytesUsed;
    final quotaLeft = user.hasQuota ? user.quotaBytes - used : null;

    // the disk can be the tighter limit even with a generous quota
    final limit = switch ((quotaLeft, diskFree)) {
      (null, final free) => free,
      (final left, < 0) => left!,
      (final left, final free) => left! < free ? left : free,
    };
    // only a floor. An upper clamp here used to be written as `1 << 62`, which
    // is fine on the vm and wrong on the web: dart compiles a shift to
    // javascript's 32 bit bitwise operator, so the bound wrapped to something
    // tiny and clamped a real 14 GB of free space down to zero.
    final remaining = limit < 0 ? 0 : limit;

    final capacity = used + remaining;
    final fraction = capacity <= 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0);
    final diskIsTheLimit =
        user.hasQuota && diskFree >= 0 && diskFree < quotaLeft!;

    final labels = Theme.of(context).textTheme.labelSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LdProgressBar(value: fraction, height: 6),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                l10n.sidebarStorageUsed(LdFormat.bytes(context, used)),
                style: labels,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.sidebarStorageFree(LdFormat.bytes(context, remaining)),
                style: labels?.copyWith(color: LdColors.foregroundMuted),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // worth saying, because otherwise the free figure looks like it
        // contradicts the quota the account was given
        if (diskIsTheLimit) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.sidebarStorageDiskLimited,
            style: labels?.copyWith(color: LdColors.accentWarning),
            maxLines: 2,
          ),
        ],
      ],
    );
  }
}

/// The create sheet: upload files, or make a folder. One entry point, reached
/// from the pill bar on mobile and the sidebar button on desktop.
Future<void> unawaitedCreate(
  BuildContext context,
  WidgetRef ref, {
  Offset? anchor,
}) async {
  final l10n = L10n.of(context);
  final location = currentLocation(context);
  final folderId = Routes.folderIdIn(location) ?? '';

  final choice = await LdContextMenu.show(
    context,
    title: l10n.navCreate,
    anchor: anchor,
    actions: <LdMenuAction>[
      LdMenuAction(id: 'folder', label: l10n.newFolder, glyph: LdGlyph.folder),
      LdMenuAction(id: 'file', label: l10n.uploadFile, glyph: LdGlyph.upload),
    ],
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'folder') {
    await showNewFolderSheet(context, ref, parentId: folderId);
    return;
  }

  await pickAndUpload(context, ref, folderId);
}
