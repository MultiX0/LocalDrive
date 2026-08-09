import '../../../core/enums/file_category.dart';

/// The owner badge on a shared item: a face and a name, which reads faster
/// than a generic share glyph and answers the real question in one glance.
class NodeOwner {
  const NodeOwner({
    required this.id,
    required this.name,
    required this.avatarSeed,
  });

  final String id;
  final String name;
  final String avatarSeed;

  factory NodeOwner.fromJson(Map<String, dynamic> json) => NodeOwner(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarSeed: json['avatar_seed'] as String? ?? '',
      );
}

/// A file or a folder, plus everything the client needs to render its tile.
class NodeModel {
  const NodeModel({
    required this.id,
    required this.name,
    required this.isFolder,
    required this.category,
    required this.libraryId,
    this.parentId = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.checksum = '',
    this.color,
    this.hasThumbnail = false,
    this.previewable = false,
    this.versionCount = 1,
    this.starred = false,
    this.sharedWithMe = false,
    this.hasActiveShare = false,
    this.role = AccessRole.none,
    this.owner,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.takenAt = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.trashedAt = 0,
  });

  final String id;
  final String name;
  final bool isFolder;
  final FileCategory category;
  final String libraryId;
  final String parentId;
  final String mimeType;
  final int sizeBytes;
  final String checksum;
  final String? color;
  final bool hasThumbnail;
  final bool previewable;
  final int versionCount;
  final bool starred;
  final bool sharedWithMe;
  final bool hasActiveShare;
  final AccessRole role;
  final NodeOwner? owner;

  /// pixel dimensions, so the gallery can lay out a masonry grid before a
  /// single thumbnail has arrived. Zero for anything that is not an image
  final int imageWidth;
  final int imageHeight;

  /// when the picture was taken, which is not when it was uploaded. Zero when
  /// the file carries no capture time
  final int takenAt;
  final int createdAt;
  final int updatedAt;
  final int trashedAt;

  bool get isTrashed => trashedAt > 0;

  /// The shape of the picture, for laying it out before it has loaded. Falls
  /// back to a square, which is the least wrong guess when the server has not
  /// probed the file yet.
  double get aspectRatio =>
      imageWidth > 0 && imageHeight > 0 ? imageWidth / imageHeight : 1;

  /// When this was taken, falling back to when it was uploaded. Without the
  /// fallback every screenshot and download would pile up at one end of a
  /// gallery sorted by capture time.
  int get capturedAt => takenAt > 0 ? takenAt : createdAt;

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    return NodeModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isFolder: json['type'] == 'folder',
      category: FileCategory.fromName(json['category'] as String?),
      libraryId: json['library_id'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      checksum: json['checksum_sha256'] as String? ?? '',
      color: json['color'] as String?,
      hasThumbnail: json['has_thumbnail'] as bool? ?? false,
      previewable: json['previewable'] as bool? ?? false,
      versionCount: json['version_count'] as int? ?? 1,
      starred: json['starred'] as bool? ?? false,
      sharedWithMe: json['shared_with_me'] as bool? ?? false,
      hasActiveShare: json['has_active_share'] as bool? ?? false,
      role: AccessRole.fromName(json['role'] as String?),
      owner: ownerJson is Map<String, dynamic>
          ? NodeOwner.fromJson(ownerJson)
          : null,
      imageWidth: json['image_width'] as int? ?? 0,
      imageHeight: json['image_height'] as int? ?? 0,
      takenAt: json['taken_at'] as int? ?? 0,
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      trashedAt: json['trashed_at'] as int? ?? 0,
    );
  }

  /// The server's own shape, so a cached row round trips through
  /// [NodeModel.fromJson] with nothing lost.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': isFolder ? 'folder' : 'file',
        'category': category.name,
        'library_id': libraryId,
        'parent_id': parentId,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'checksum_sha256': checksum,
        'color': color,
        'has_thumbnail': hasThumbnail,
        'previewable': previewable,
        'version_count': versionCount,
        'starred': starred,
        'shared_with_me': sharedWithMe,
        'has_active_share': hasActiveShare,
        'role': role.name,
        'owner': owner == null
            ? null
            : <String, dynamic>{
                'id': owner!.id,
                'name': owner!.name,
                'avatar_seed': owner!.avatarSeed,
              },
        'image_width': imageWidth,
        'image_height': imageHeight,
        'taken_at': takenAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'trashed_at': trashedAt,
      };

  NodeModel copyWith({
    String? name,
    String? parentId,
    String? color,
    bool? starred,
    bool? hasThumbnail,
    bool? hasActiveShare,
    int? updatedAt,
  }) =>
      NodeModel(
        id: id,
        name: name ?? this.name,
        isFolder: isFolder,
        category: category,
        libraryId: libraryId,
        parentId: parentId ?? this.parentId,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        checksum: checksum,
        color: color ?? this.color,
        hasThumbnail: hasThumbnail ?? this.hasThumbnail,
        previewable: previewable,
        versionCount: versionCount,
        starred: starred ?? this.starred,
        sharedWithMe: sharedWithMe,
        hasActiveShare: hasActiveShare ?? this.hasActiveShare,
        role: role,
        owner: owner,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        takenAt: takenAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        trashedAt: trashedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is NodeModel &&
      other.id == id &&
      other.name == name &&
      other.updatedAt == updatedAt &&
      other.starred == starred &&
      other.color == color &&
      other.hasThumbnail == hasThumbnail &&
      other.hasActiveShare == hasActiveShare;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        updatedAt,
        starred,
        color,
        hasThumbnail,
        hasActiveShare,
      );
}

/// One prior state of a file.
class NodeVersionModel {
  const NodeVersionModel({
    required this.id,
    required this.sizeBytes,
    required this.createdAt,
    this.mimeType = '',
    this.createdBy = '',
  });

  final String id;
  final int sizeBytes;
  final int createdAt;
  final String mimeType;
  final String createdBy;

  factory NodeVersionModel.fromJson(Map<String, dynamic> json) =>
      NodeVersionModel(
        id: json['id'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        createdAt: json['created_at'] as int? ?? 0,
        mimeType: json['mime_type'] as String? ?? '',
        createdBy: json['created_by'] as String? ?? '',
      );
}

/// One thumbnail peeking out of a folder's icon.
class NodePreviewModel {
  const NodePreviewModel({required this.nodeId, required this.thumbnailUrl});

  final String nodeId;
  final String thumbnailUrl;

  factory NodePreviewModel.fromJson(Map<String, dynamic> json) =>
      NodePreviewModel(
        nodeId: json['node_id'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      );
}
