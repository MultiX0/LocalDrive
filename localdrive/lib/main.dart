import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/constants/ld_colors.dart';
import 'core/services/desktop_shell_service.dart';
import 'core/widgets/ld_error_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv, loaded once before anything asks for a player. video_player had no
  // Windows implementation at all, and the community one handed the URL to
  // Media Foundation, which pulled the whole file down before showing a frame.
  MediaKit.ensureInitialized();

  // removes the /#/ from web urls. this is only half the fix: Caddy also
  // serves index.html for any path that is not a real asset, or a refresh on
  // /files/abc123 would 404. see the routing section of the plan.
  usePathUrlStrategy();

  // nothing unstyled ever reaches the screen, including the frame that a
  // widget error would otherwise paint red
  ErrorWidget.builder = (details) {
    if (kDebugMode) {
      debugPrint('widget error: ${details.exceptionAsString()}');
    }
    return const _GlobalErrorSurface();
  };

  // a desktop window is resizable and a phone is not; asking a desktop
  // platform about orientation is meaningless and throws on some of them
  if (!kIsWeb && !DesktopShellService.isDesktop) {
    await _lockOrientations();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: LdColors.backgroundPrimary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // the desktop window starts hidden so there is no flash of the system title
  // bar before the app's own one is in place. This is what shows it
  DesktopShellService.showWindow();

  runApp(const ProviderScope(child: LocalDriveApp()));
}

Future<void> _lockOrientations() async {
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// The branded surface behind the global ErrorWidget.builder override, for an
/// error no screen anticipated. It cannot reach Localizations, since the
/// failure may be above them, so it stays wordless rather than hardcoding
/// English.
class _GlobalErrorSurface extends StatelessWidget {
  const _GlobalErrorSurface();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: LdColors.backgroundPrimary,
      child: LdErrorState(
        kind: LdErrorKind.unexpected,
        title: '',
        compact: true,
      ),
    );
  }
}
