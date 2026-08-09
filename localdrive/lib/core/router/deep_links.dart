import '../services/api_client.dart';
import 'routes.dart';

/// What a link from outside the app resolves to.
///
/// Local Drive is not one service with one domain, it is potentially many
/// self hosted servers, so a bare path is ambiguous without knowing which
/// server it belongs to. That is why this carries the server address as well
/// as the in-app path: the app can then check whether it is connected to the
/// right one and offer to switch rather than silently opening the wrong thing.
class DeepLink {
  const DeepLink({required this.path, this.serverUrl = ''});

  /// the in-app route, always one of the same paths every platform uses
  final String path;

  /// the absolute address of the server the link belongs to, empty when the
  /// link did not name one (a custom scheme link usually does not)
  final String serverUrl;

  bool get namesServer => serverUrl.isNotEmpty;
}

/// Turns a link into a route, or null if it is not one of ours.
///
/// Three shapes arrive here and all three mean the same thing:
///
///   https://drive.example/s/abc      a Universal Link or App Link
///   localdrive://s/abc               the custom scheme fallback
///   localdrive:///s/abc              the same, written with an empty host
///
/// The scheme form exists because verified links need a domain that serves an
/// assetlinks.json or an apple-app-site-association file, and a self hosted
/// server on a bare IP has neither.
DeepLink? parseDeepLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || raw.trim().isEmpty) return null;

  final custom = uri.scheme == 'localdrive';
  if (!custom && uri.scheme != 'http' && uri.scheme != 'https') return null;

  // localdrive://files/abc parses the first segment as the host, not the path,
  // so the host is folded back in when it is one of our own route roots
  final segments = <String>[
    if (custom && uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((segment) => segment.isNotEmpty),
  ];
  if (segments.isEmpty) return null;

  final serverUrl = custom
      ? ''
      : Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null)
          .toString();

  final path = switch (segments.first) {
    // the public share link, which needs no session at all
    's' when segments.length > 1 => Routes.publicShare(segments[1]),
    'invite' when segments.length > 1 => Routes.inviteLink(segments[1]),
    'files' => segments.length > 1 ? Routes.folder(segments[1]) : Routes.files,
    'shared' => Routes.shared,
    'settings' => '/${segments.join('/')}',
    // the extension on iOS opens localdrive://share once it has copied files
    // into the shared container. It is a wake up call, not a destination
    'share' => Routes.transfers,
    _ => null,
  };
  if (path == null) return null;

  return DeepLink(path: path, serverUrl: serverUrl);
}

/// Whether a link's server is the one this device is currently signed in to.
///
/// Compared on scheme, host and port rather than as strings, so a trailing
/// slash or a default port written out does not read as a different server.
bool linkMatchesNode(String linkServerUrl, String connectedNodeUrl) {
  if (linkServerUrl.isEmpty || connectedNodeUrl.isEmpty) return true;
  final a = Uri.tryParse(linkServerUrl);
  final b = Uri.tryParse(connectedNodeUrl);
  if (a == null || b == null) return true;

  final portA = a.hasPort ? a.port : _defaultPort(a.scheme);
  final portB = b.hasPort ? b.port : _defaultPort(b.scheme);
  return a.host == b.host && portA == portB;
}

int _defaultPort(String scheme) => switch (scheme) {
      'http' => 80,
      'https' => 443,
      _ => ApiClient.defaultPort,
    };
