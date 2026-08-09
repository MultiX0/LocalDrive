/// Keys for secure storage and preferences, declared once.
abstract final class StorageKeys {
  // secure, keychain and keystore backed
  static const String accessToken = 'ld.access_token';
  static const String refreshToken = 'ld.refresh_token';
  static const String sessionId = 'ld.session_id';
  static const String nodeUrl = 'ld.node_url';
  static const String knownNodes = 'ld.known_nodes';

  // plain preferences, nothing sensitive
  static const String localeCode = 'ld.locale';
  static const String viewMode = 'ld.view_mode';
  static const String sortBy = 'ld.sort_by';
  static const String sortDescending = 'ld.sort_descending';
  static const String gallerySort = 'ld.gallery_sort';
  static const String gallerySortDescending = 'ld.gallery_sort_descending';
  static const String galleryGrouping = 'ld.gallery_grouping';
  static const String galleryColumns = 'ld.gallery_columns';
  static const String offlineSoftCapBytes = 'ld.offline_soft_cap';
  static const String notificationsAsked = 'ld.notifications_asked';
  static const String localNetworkAsked = 'ld.local_network_asked';
}

/// WebSocket event names, matching the server's constants exactly.
/// [deviceDenied] and [settingsChanged] are sent by the server but not
/// handled on this side yet.
abstract final class WsEvents {
  static const String nodeCreated = 'node.created';
  static const String nodeUpdated = 'node.updated';
  static const String nodeMoved = 'node.moved';
  static const String nodeDeleted = 'node.deleted';
  static const String nodeRestored = 'node.restored';
  static const String thumbnailReady = 'node.thumbnail_ready';
  static const String quotaUpdated = 'quota.updated';
  static const String devicePending = 'device.pending';
  static const String deviceApproved = 'device.approved';
  static const String deviceDenied = 'device.denied';
  static const String shareReceived = 'share.received';
  static const String libraryChanged = 'library.changed';
  static const String settingsChanged = 'server.settings_changed';
  static const String sessionRevoked = 'session.revoked';
}

/// Durations that are policy rather than motion.
abstract final class AppDurations {
  /// how often a device waiting for approval polls, no faster, so a phone in
  /// someone's pocket is not doing constant network work while it waits
  static const Duration approvalPoll = Duration(milliseconds: 4500);

  static const Duration lanScan = Duration(seconds: 5);

  /// the shortest a network scan is allowed to appear to take. finding nothing
  /// in eighty milliseconds reads as a broken feature rather than an honest
  /// answer, so the radar always sweeps for at least this long
  static const Duration lanScanMinimum = Duration(milliseconds: 2200);
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration reconnectMin = Duration(seconds: 1);
  static const Duration reconnectMax = Duration(seconds: 60);
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);

  /// transfer retry backoff, capped around a minute
  static const Duration retryBase = Duration(seconds: 2);
  static const Duration retryMax = Duration(seconds: 60);
}

/// How many transfers run at once. The rest are genuinely queued behind them,
/// so a bulk upload does not try to open hundreds of connections.
abstract final class TransferLimits {
  static const int concurrentUploads = 3;
  static const int concurrentDownloads = 3;
  static const int chunkBytes = 5 * 1024 * 1024;
  static const int defaultOfflineSoftCapBytes = 2 * 1024 * 1024 * 1024;
}
