import '../../../core/enums/file_category.dart';

/// A public, tokenized link to one node.
class ShareModel {
  const ShareModel({
    required this.id,
    required this.nodeId,
    required this.token,
    required this.url,
    required this.allowDownload,
    required this.passwordProtected,
    required this.active,
    this.expiresAt = 0,
    this.createdAt = 0,
    this.revokedAt = 0,
  });

  final String id;
  final String nodeId;
  final String token;

  /// always an absolute url to its own server, since a bare path is ambiguous
  /// across self-hosted nodes
  final String url;
  final bool allowDownload;
  final bool passwordProtected;
  final bool active;
  final int expiresAt;
  final int createdAt;
  final int revokedAt;

  bool get expires => expiresAt > 0;

  /// [resolveUrl] fills in the connected server's address when the server
  /// sent a bare path, which is the ordinary case for a self-hosted install
  /// with no domain. See [ApiClient.publicLink].
  factory ShareModel.fromJson(
    Map<String, dynamic> json, {
    required String Function(String) resolveUrl,
  }) =>
      ShareModel(
        id: json['id'] as String? ?? '',
        nodeId: json['node_id'] as String? ?? '',
        token: json['token'] as String? ?? '',
        url: resolveUrl(json['url'] as String? ?? ''),
        allowDownload: json['allow_download'] as bool? ?? true,
        passwordProtected: json['password_protected'] as bool? ?? false,
        active: json['active'] as bool? ?? false,
        expiresAt: json['expires_at'] as int? ?? 0,
        createdAt: json['created_at'] as int? ?? 0,
        revokedAt: json['revoked_at'] as int? ?? 0,
      );
}

/// What a public link resolves to for someone holding it and nothing else.
///
/// This is deliberately not a NodeModel. A visitor with a link has no session,
/// no role on the node, and no business seeing its checksum or its place in
/// someone else's tree, and the server strips those before answering. Reusing
/// NodeModel here would invite a screen to reach for a field that is never
/// populated on this path.
class PublicShareModel {
  const PublicShareModel({
    required this.name,
    required this.category,
    required this.sizeBytes,
    required this.ownerName,
    required this.allowDownload,
    this.isFolder = false,
    this.expiresAt = 0,
    this.updatedAt = 0,
  });

  final String name;
  final FileCategory category;
  final int sizeBytes;
  final String ownerName;
  final bool allowDownload;
  final bool isFolder;
  final int expiresAt;
  final int updatedAt;

  factory PublicShareModel.fromJson(Map<String, dynamic> json) {
    final node = json['node'] as Map<String, dynamic>? ?? const {};
    return PublicShareModel(
      name: node['name'] as String? ?? '',
      category: FileCategory.fromName(node['category'] as String?),
      sizeBytes: node['size_bytes'] as int? ?? 0,
      ownerName: json['owner_name'] as String? ?? '',
      allowDownload: json['allow_download'] as bool? ?? true,
      isFolder: (node['is_folder'] as bool?) ??
          (node['category'] as String?) == 'folder',
      expiresAt: json['expires_at'] as int? ?? 0,
      updatedAt: node['updated_at'] as int? ?? 0,
    );
  }
}

/// One person's access to one node.
class GrantModel {
  const GrantModel({
    required this.userId,
    required this.name,
    required this.avatarSeed,
    required this.role,
    this.createdAt = 0,
  });

  final String userId;
  final String name;
  final String avatarSeed;
  final String role;
  final int createdAt;

  bool get isEditor => role == 'editor';

  factory GrantModel.fromJson(Map<String, dynamic> json) => GrantModel(
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarSeed: json['avatar_seed'] as String? ?? '',
        role: json['role'] as String? ?? 'viewer',
        createdAt: json['created_at'] as int? ?? 0,
      );
}

/// An account as the People picker sees it: a face and a name, never an email
/// or a role.
class PersonModel {
  const PersonModel({
    required this.id,
    required this.name,
    required this.avatarSeed,
    this.nearby = false,
  });

  final String id;
  final String name;
  final String avatarSeed;

  /// set locally by the nearby beacon, never by the server
  final bool nearby;

  PersonModel copyWith({bool? nearby}) => PersonModel(
        id: id,
        name: name,
        avatarSeed: avatarSeed,
        nearby: nearby ?? this.nearby,
      );

  factory PersonModel.fromJson(Map<String, dynamic> json) => PersonModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarSeed: json['avatar_seed'] as String? ?? '',
      );
}
