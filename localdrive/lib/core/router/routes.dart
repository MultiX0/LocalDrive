import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Route paths and names, declared once. The same structure serves a web URL,
/// an Android App Link, an iOS Universal Link, an invite link, and a public
/// share link; there is no web-specific set and separate mobile-specific set.
abstract final class Routes {
  // onboarding and auth
  static const String welcome = '/welcome';
  static const String connect = '/connect';
  static const String language = '/language';
  static const String setup = '/setup';
  static const String signIn = '/signin';
  static const String createAccount = '/create-account';
  static const String pendingApproval = '/pending';
  static const String changePassword = '/change-password';
  static const String twoFactorSetup = '/two-factor';

  // the main app
  static const String files = '/files';
  static const String shared = '/shared';
  static const String gallery = '/gallery';
  static const String starred = '/starred';
  static const String recent = '/recent';
  static const String trash = '/trash';
  static const String search = '/search';
  static const String activity = '/activity';
  static const String storage = '/storage';
  static const String transfers = '/transfers';
  static const String preview = '/preview';

  // settings
  static const String settings = '/settings';
  static const String settingsAccount = '$settings/account';
  static const String settingsDevices = '$settings/devices';
  static const String settingsUsers = '$settings/users';
  static const String settingsServer = '$settings/server';
  static const String settingsLanguage = '$settings/language';
  static const String settingsDownloads = '$settings/downloads';
  static const String settingsAbout = '$settings/about';

  // links from outside the app
  static const String share = '/s';
  static const String invite = '/invite';

  // Builders. Every route that takes an id goes through one of these rather
  // than being written out at the call site, so the base path exists once and
  // a change to it cannot leave a stale copy behind.
  static String folder(String nodeId) => child(files, nodeId);
  static String photo(String nodeId) => child(gallery, nodeId);
  static String sharedNode(String nodeId) => child(shared, nodeId);
  static String previewOf(String nodeId) => child(preview, nodeId);
  static String settingsSection(String id) => child(settings, id);
  static String publicShare(String token) => child(share, token);
  static String inviteLink(String code) => child(invite, code);

  /// The path pattern go_router registers for a child route, as in `:id`.
  static String pattern(String parameter) => ':$parameter';

  static String child(String base, String segment) =>
      '$base/${Uri.encodeComponent(segment)}';

  /// The id in a location like `/files/abc123`, or null when the location is
  /// the base itself or something else entirely.
  ///
  /// Reading this back was open coded in a few places as a `startsWith` and a
  /// `substring` with the prefix length written out twice, which is the kind
  /// of thing that works until someone changes the base path.
  static String? idIn(String base, String location) {
    final prefix = '$base/';
    if (!location.startsWith(prefix)) return null;
    final rest = location.substring(prefix.length);
    if (rest.isEmpty) return null;
    // only the first segment; anything deeper belongs to another route
    final end = rest.indexOf('/');
    final value = end == -1 ? rest : rest.substring(0, end);
    return value.isEmpty ? null : Uri.decodeComponent(value);
  }

  /// The folder a location is showing, or null at the root of the browser.
  static String? folderIdIn(String location) => idIn(files, location);

  /// the custom scheme registered on every platform, used as the fallback
  /// where App Links or Universal Links are not verified
  static const String scheme = 'localdrive';
}

/// The location the router is currently showing.
///
/// `GoRouterState.of` only works inside the subtree of the matched route, so a
/// ShellRoute builder's own context cannot use it. The delegate's current
/// configuration is readable from anywhere under the router, which is what the
/// navigation chrome needs.
String currentLocation(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return Routes.files;
  final configuration = router.routerDelegate.currentConfiguration;
  if (configuration.isEmpty) return Routes.files;
  return configuration.uri.path;
}
