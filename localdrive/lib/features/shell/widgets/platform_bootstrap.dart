import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/services/desktop_shell_service.dart';
import '../../../imports.dart';
import '../../auth/controller/session_controller.dart';
import '../../auth/controller/session_state.dart';

/// The platform work that has to happen inside the widget tree, because it
/// needs localized copy or a place to show a sheet.
///
/// The tray menu is as much part of the app as any screen and belongs in the
/// person's own language. The notification prompt has to explain itself before
/// the system asks, so it needs somewhere to put a sheet. Neither can happen
/// in `main`, which is why this is a widget and not a service call.
class PlatformBootstrap extends ConsumerStatefulWidget {
  const PlatformBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlatformBootstrap> createState() => _PlatformBootstrapState();
}

class _PlatformBootstrapState extends ConsumerState<PlatformBootstrap> {
  DesktopShellService? _shell;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    if (!mounted) return;
    await _startTray();
    await _askAboutNotifications();
  }

  Future<void> _startTray() async {
    if (!DesktopShellService.isDesktop || !mounted) return;
    final l10n = L10n.of(context);

    final shell = DesktopShellService(
      menuLabels: (
        open: l10n.trayOpen,
        transfers: l10n.trayTransfers,
        quit: l10n.trayQuit,
      ),
      onShow: () {
        if (mounted) context.go(Routes.transfers);
      },
      onQuit: () async {
        await _shell?.dispose();
        // a real quit, unlike the window's close button, which only hides
        await SystemNavigator.pop();
      },
    );
    _shell = shell;
    await shell.start();
  }

  /// Asks for notification permission only after explaining why, and only
  /// once.
  ///
  /// A cold system prompt on first launch is the reason so many people have
  /// notifications off for apps that genuinely need them. Here the permission
  /// is what keeps a transfer alive after the screen turns off, so it is worth
  /// a sentence first, and worth accepting a no.
  Future<void> _askAboutNotifications() async {
    if (kIsWeb || !mounted) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // only for someone actually signed in: there is nothing to notify about
    // on the connect screen
    if (ref.read(sessionProvider).stage != SessionStage.ready) return;

    final store = ref.read(secureStoreProvider);
    if (await store.readBool(StorageKeys.notificationsAsked)) return;
    if (!mounted) return;

    final l10n = L10n.of(context);
    final proceed = await LdBottomSheet.confirm(
      context,
      title: l10n.notificationsWhyTitle,
      message: l10n.notificationsWhyBody,
      confirmLabel: l10n.notificationsAllow,
      cancelLabel: l10n.notificationsNotNow,
    );

    // asked, whatever the answer. A no is a real answer and is not re-asked
    await store.writeBool(StorageKeys.notificationsAsked, true);
    if (!proceed) return;

    final plugin = FlutterLocalNotificationsPlugin();
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return;
    }
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: false);
  }

  @override
  void dispose() {
    unawaited(_shell?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
