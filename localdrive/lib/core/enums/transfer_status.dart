/// The transfer state machine from the reliability section of the plan.
/// A transfer is queued, in progress, retrying with a visible reason, or
/// failed with a clear reason and a retry button. There is no fourth, silent
/// state.
enum TransferStatus {
  queued,
  inProgress,
  retrying,
  paused,
  completed,
  failed;

  static TransferStatus fromName(String raw) => TransferStatus.values
      .firstWhere((s) => s.name == raw, orElse: () => TransferStatus.queued);

  bool get isActive =>
      this == TransferStatus.inProgress || this == TransferStatus.retrying;
  bool get isFinished =>
      this == TransferStatus.completed || this == TransferStatus.failed;
  bool get needsAttention => this == TransferStatus.failed;
}

/// Which direction a queued transfer runs in.
enum TransferKind {
  upload,
  download;

  static TransferKind fromName(String raw) => TransferKind.values
      .firstWhere((k) => k.name == raw, orElse: () => TransferKind.upload);
}

/// Why a transfer failed, which decides whether retrying could ever help.
enum FailureReason {
  /// plausibly transient: a dropped connection, a timeout, a 5xx
  network,
  server,

  /// not transient: retrying forever at these would never succeed on its own
  sessionExpired,
  permission,
  quota,
  notFound,
  fileMissing,
  unknown;

  bool get isTransient =>
      this == FailureReason.network || this == FailureReason.server;

  static FailureReason fromName(String? raw) => FailureReason.values
      .firstWhere((r) => r.name == raw, orElse: () => FailureReason.unknown);
}
