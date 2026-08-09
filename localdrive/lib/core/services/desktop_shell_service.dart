import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tray_manager/tray_manager.dart';

/// The desktop window and tray.
///
/// Closing the window on a desktop app is not the same as quitting it. A
/// transfer that was halfway through has no reason to die because someone
/// clicked the X, so the window hides to the tray instead and the queue keeps
/// running. Quit is a deliberate choice from the tray menu, which is also the
/// only place that can honestly offer it.
class DesktopShellService with TrayListener {
  DesktopShellService({this.onShow, this.onQuit, required this.menuLabels});

  /// Whether this platform has a window and a tray at all.
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  final void Function()? onShow;
  final Future<void> Function()? onQuit;

  /// Localized, because a tray menu is as much part of the app as any screen.
  /// Passed in rather than read here, since this runs outside the widget tree
  /// and has no BuildContext to reach Localizations through.
  final ({String open, String transfers, String quit}) menuLabels;

  bool _started = false;

  /// True once `main` has taken the real window over.
  ///
  /// The title bar checks this rather than only checking the platform, because
  /// a widget test runs on a desktop host with no window behind it at all, and
  /// reaching for `appWindow` there throws.
  static bool get hasWindow => _hasWindow;
  static bool _hasWindow = false;

  /// Sizes and shows the window. Called once, after the first frame, because
  /// bitsdojo starts the window hidden so there is no flash of default chrome.
  static void showWindow() {
    if (!isDesktop) return;
    _hasWindow = true;
    doWhenWindowReady(() {
      const initial = Size(1180, 780);
      appWindow
        ..minSize = const Size(720, 560)
        ..size = initial
        ..alignment = Alignment.center
        ..title = 'Local Drive'
        ..show();
    });
  }

  Future<void> start() async {
    if (!isDesktop || _started) return;
    _started = true;

    trayManager.addListener(this);
    // the same mark the app draws, as a platform icon. Windows insists on
    // .ico; the other two are happy with a png
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/logo/tray.ico'
          : 'assets/logo/tray.png',
    );
    await trayManager.setToolTip('Local Drive');
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(key: 'open', label: menuLabels.open),
          MenuItem(key: 'transfers', label: menuLabels.transfers),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: menuLabels.quit),
        ],
      ),
    );
  }

  /// Whether the app starts itself when this machine is signed into. Off by
  /// default: a self hosted file client is not something to add to someone's
  /// login items without asking.
  Future<bool> launchAtStartupEnabled() async {
    if (!isDesktop) return false;
    return launchAtStartup.isEnabled();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    if (!isDesktop) return;
    final info = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: info.appName,
      appPath: Platform.resolvedExecutable,
      packageName: info.packageName,
    );
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  @override
  void onTrayIconMouseDown() {
    // one click brings it back, which is what everyone tries first
    appWindow.show();
    onShow?.call();
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
      case 'transfers':
        appWindow.show();
        onShow?.call();
      case 'quit':
        onQuit?.call();
    }
  }

  Future<void> dispose() async {
    if (!isDesktop || !_started) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
