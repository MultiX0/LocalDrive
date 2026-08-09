/// The signed-in account, as the server describes it.
class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.avatarSeed,
    this.email = '',
    this.quotaBytes = 0,
    this.quotaBytesUsed = 0,
    this.mustChangePassword = false,
    this.totpEnabled = false,
    this.mustEnableTotp = false,
    this.createdAt = 0,
  });

  final String id;
  final String username;
  final String displayName;
  final String role;
  final String avatarSeed;
  final String email;
  final int quotaBytes;
  final int quotaBytesUsed;
  final bool mustChangePassword;
  final bool totpEnabled;

  /// an admin who has not set up two factor yet. Members choose for
  /// themselves; an admin can reset passwords and remove accounts, so that
  /// account is not left on a password alone.
  final bool mustEnableTotp;
  final int createdAt;

  bool get isAdmin => role == 'admin';

  /// zero means unlimited, which is a real setting rather than an error state
  bool get hasQuota => quotaBytes > 0;

  double get quotaFraction =>
      hasQuota ? (quotaBytesUsed / quotaBytes).clamp(0.0, 1.0) : 0;

  int get quotaFreeBytes =>
      hasQuota ? (quotaBytes - quotaBytesUsed).clamp(0, quotaBytes) : 0;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String? ??
            json['username'] as String? ??
            '',
        role: json['role'] as String? ?? 'member',
        avatarSeed: json['avatar_seed'] as String? ?? '',
        email: json['email'] as String? ?? '',
        quotaBytes: json['quota_bytes'] as int? ?? 0,
        quotaBytesUsed: json['quota_bytes_used'] as int? ?? 0,
        mustChangePassword: json['must_change_password'] as bool? ?? false,
        totpEnabled: json['totp_enabled'] as bool? ?? false,
        mustEnableTotp: json['must_enable_totp'] as bool? ?? false,
        createdAt: json['created_at'] as int? ?? 0,
      );

  UserModel copyWith({
    String? displayName,
    int? quotaBytes,
    int? quotaBytesUsed,
    bool? mustChangePassword,
    bool? totpEnabled,
    bool? mustEnableTotp,
  }) =>
      UserModel(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        role: role,
        avatarSeed: avatarSeed,
        email: email,
        quotaBytes: quotaBytes ?? this.quotaBytes,
        quotaBytesUsed: quotaBytesUsed ?? this.quotaBytesUsed,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        totpEnabled: totpEnabled ?? this.totpEnabled,
        mustEnableTotp: mustEnableTotp ?? this.mustEnableTotp,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is UserModel &&
      other.id == id &&
      other.displayName == displayName &&
      other.quotaBytesUsed == quotaBytesUsed &&
      other.quotaBytes == quotaBytes &&
      other.mustChangePassword == mustChangePassword &&
      other.totpEnabled == totpEnabled;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        quotaBytesUsed,
        quotaBytes,
        mustChangePassword,
        totpEnabled,
      );
}

/// What GET /status reports about a node, before anyone signs in. It says
/// nothing about users or contents on purpose.
class ServerStatusModel {
  const ServerStatusModel({
    required this.name,
    required this.serverId,
    required this.version,
    required this.setupRequired,
    required this.requireDeviceApproval,
    required this.allowSelfRegistration,
    required this.ready,
  });

  final String name;
  final String serverId;
  final String version;
  final bool setupRequired;
  final bool requireDeviceApproval;
  final bool allowSelfRegistration;

  /// whether an active library is configured, which is what the ready or
  /// needs-setup indicator in onboarding shows
  final bool ready;

  factory ServerStatusModel.fromJson(Map<String, dynamic> json) =>
      ServerStatusModel(
        name: json['name'] as String? ?? '',
        serverId: json['server_id'] as String? ?? '',
        version: json['version'] as String? ?? '',
        setupRequired: json['setup_required'] as bool? ?? false,
        requireDeviceApproval:
            json['require_device_approval'] as bool? ?? false,
        allowSelfRegistration:
            json['allow_self_registration'] as bool? ?? false,
        ready: json['ready'] as bool? ?? false,
      );
}

/// One device on the account.
class SessionModel {
  const SessionModel({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.status,
    required this.ip,
    required this.createdAt,
    required this.lastSeenAt,
    this.userId = '',
    this.current = false,
  });

  final String id;
  final String deviceName;
  final String platform;
  final String status;
  final String ip;
  final int createdAt;
  final int lastSeenAt;
  final String userId;
  final bool current;

  bool get isPending => status == 'pending';

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        id: json['id'] as String? ?? '',
        deviceName: json['device_name'] as String? ?? '',
        platform: json['platform'] as String? ?? '',
        status: json['status'] as String? ?? '',
        ip: json['ip'] as String? ?? '',
        createdAt: json['created_at'] as int? ?? 0,
        lastSeenAt: json['last_seen_at'] as int? ?? 0,
        userId: json['user_id'] as String? ?? '',
        current: json['current'] as bool? ?? false,
      );
}
