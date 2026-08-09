/// Every API path, declared once. Nothing builds a URL from an inline literal.
abstract final class Api {
  static const String prefix = '/api/v1';

  // unauthenticated
  static const String status = '$prefix/status';
  static const String setup = '$prefix/setup';
  static const String register = '$prefix/auth/register';
  static const String login = '$prefix/auth/login';
  static const String refresh = '$prefix/auth/refresh';
  static const String logout = '$prefix/auth/logout';
  static String checkInvite(String code) => '$prefix/invites/$code/check';
  static String sessionStatus(String id) => '$prefix/auth/session/$id/status';

  // account
  static const String me = '$prefix/me';
  static const String mePassword = '$prefix/me/password';
  static const String meProfile = '$prefix/me/profile';
  static const String totpBegin = '$prefix/auth/2fa/begin';
  static const String totpVerify = '$prefix/auth/2fa/verify';
  static const String totpDisable = '$prefix/auth/2fa/disable';
  static const String users = '$prefix/users';

  // nodes
  static const String nodes = '$prefix/nodes';
  static const String folder = '$prefix/nodes/folder';
  static String node(String id) => '$prefix/nodes/$id';
  static String nodePath(String id) => '$prefix/nodes/$id/path';
  static String star(String id) => '$prefix/nodes/$id/star';
  static String restore(String id) => '$prefix/nodes/$id/restore';
  static String permanent(String id) => '$prefix/nodes/$id/permanent';
  static String preview(String id) => '$prefix/nodes/$id/preview';
  static String download(String id) => '$prefix/nodes/$id/download';
  static String thumbnail(String id) => '$prefix/nodes/$id/thumbnail';
  static String versions(String id) => '$prefix/nodes/$id/versions';
  static String restoreVersion(String id, String versionId) =>
      '$prefix/nodes/$id/versions/$versionId/restore';

  // sharing
  static String nodeShares(String id) => '$prefix/nodes/$id/shares';
  static String createShare(String id) => '$prefix/nodes/$id/share';
  static String share(String id) => '$prefix/shares/$id';
  static const String myShares = '$prefix/shares';
  static String permissions(String id) => '$prefix/nodes/$id/permissions';
  static String permission(String nodeId, String userId) =>
      '$prefix/nodes/$nodeId/permissions/$userId';
  static String publicShare(String token) => '/s/$token';
  static String publicShareDownload(String token) => '/s/$token/download';
  static String publicShareThumbnail(String token) => '/s/$token/thumbnail';
  static String publicShareChildren(String token) => '/s/$token/children';

  // uploads, tus
  static const String uploads = '$prefix/uploads';

  // libraries and drives
  static const String libraries = '$prefix/libraries';
  static String library(String id) => '$prefix/libraries/$id';
  static String librarySetDefault(String id) => '$prefix/libraries/$id/set-default';
  static String libraryEject(String id) => '$prefix/libraries/$id/eject';
  static const String drives = '$prefix/admin/drives';
  static String mountDrive(String id) => '$prefix/admin/drives/$id/mount';
  static String formatDrive(String id) => '$prefix/admin/drives/$id/format';
  static const String poolDrives = '$prefix/admin/drives/pool';

  // devices and sessions
  static const String sessions = '$prefix/sessions';
  static String session(String id) => '$prefix/sessions/$id';
  static const String pendingDevices = '$prefix/devices/pending';
  static String approveDevice(String id) => '$prefix/devices/$id/approve';
  static String denyDevice(String id) => '$prefix/devices/$id/deny';
  static const String adminPendingDevices = '$prefix/admin/devices/pending';

  // admin
  static const String adminUsers = '$prefix/admin/users';
  static String resetPassword(String id) => '$prefix/admin/users/$id/reset-password';
  static String userRole(String id) => '$prefix/admin/users/$id/role';
  static String userQuota(String id) => '$prefix/admin/users/$id/quota';
  static String userDisabled(String id) => '$prefix/admin/users/$id/disabled';
  static const String invites = '$prefix/admin/invites';
  static String invite(String id) => '$prefix/admin/invites/$id';

  // misc
  static const String trash = '$prefix/trash';
  static const String activity = '$prefix/activity';
  static const String serverSettings = '$prefix/server/settings';
  static const String websocket = '$prefix/ws';

  // query keys
  static const String qParentId = 'parent_id';
  static const String qFilter = 'filter';
  static const String qQuery = 'query';
  static const String qLimit = 'limit';
  static const String qOffset = 'offset';
  static const String qSort = 'sort';
  static const String qOrder = 'order';
  static const String qInline = 'inline';

  // headers
  static const String headerIdempotency = 'Idempotency-Key';
  static const String headerNodeId = 'Local-Drive-Node-Id';

  /// the sentinel the server accepts for the blended top level
  static const String rootParent = 'root';
}

/// The filters `GET /nodes` understands.
abstract final class NodeFilter {
  static const String none = '';
  static const String shared = 'shared';
  static const String gallery = 'gallery';
  static const String starred = 'starred';
  static const String recent = 'recent';
}
