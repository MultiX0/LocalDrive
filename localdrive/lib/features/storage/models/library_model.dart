/// One storage root: this server's own internal disk, an external drive, a
/// network share, or a pool of several drives seen as one.
class LibraryModel {
  const LibraryModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.isExternal,
    required this.isDefault,
    required this.status,
    required this.bytesUsed,
    this.totalBytes = 0,
    this.freeBytes = 0,
    this.statsKnown = false,
    this.members = const <String>[],
    this.createdAt = 0,
  });

  final String id;
  final String name;
  final String kind;
  final bool isExternal;
  final bool isDefault;
  final String status;
  final int bytesUsed;

  /// read live from the OS, so a stale number never misleads
  final int totalBytes;
  final int freeBytes;

  /// false for an offline drive, which reports its last known usage instead
  final bool statsKnown;
  final List<String> members;
  final int createdAt;

  bool get isOnline => status == 'online';
  bool get isPooled => kind == 'pooled';

  double get usedFraction =>
      totalBytes <= 0 ? 0 : (bytesUsed / totalBytes).clamp(0.0, 1.0);

  factory LibraryModel.fromJson(Map<String, dynamic> json) => LibraryModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        kind: json['kind'] as String? ?? 'internal',
        isExternal: json['is_external'] as bool? ?? false,
        isDefault: json['is_default'] as bool? ?? false,
        status: json['status'] as String? ?? 'online',
        bytesUsed: json['bytes_used'] as int? ?? 0,
        totalBytes: json['total_bytes'] as int? ?? 0,
        freeBytes: json['free_bytes'] as int? ?? 0,
        statsKnown: json['stats_known'] as bool? ?? false,
        members: (json['members'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
        createdAt: json['created_at'] as int? ?? 0,
      );
}

/// Every library plus the combined totals shown at the top of the screen.
class LibrarySummary {
  const LibrarySummary({
    required this.libraries,
    required this.totalUsed,
    required this.totalFree,
    required this.totalBytes,
  });

  final List<LibraryModel> libraries;
  final int totalUsed;
  final int totalFree;
  final int totalBytes;

  LibraryModel? get defaultLibrary {
    for (final library in libraries) {
      if (library.isDefault) return library;
    }
    return libraries.isEmpty ? null : libraries.first;
  }

  Iterable<LibraryModel> get offline =>
      libraries.where((library) => !library.isOnline);

  factory LibrarySummary.fromJson(Map<String, dynamic> json) => LibrarySummary(
        libraries: (json['libraries'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(LibraryModel.fromJson)
            .toList(growable: false),
        totalUsed: json['total_used'] as int? ?? 0,
        totalFree: json['total_free'] as int? ?? 0,
        totalBytes: json['total_bytes'] as int? ?? 0,
      );
}

/// A block device the helper can see, mounted or not.
class DriveModel {
  const DriveModel({
    required this.id,
    required this.name,
    required this.filesystem,
    required this.sizeBytes,
    required this.mounted,
    required this.usable,
    required this.inUse,
    this.label = '',
    this.model = '',
    this.mountPoint = '',
    this.removable = false,
    this.readOnly = false,
  });

  final String id;
  final String name;
  final String filesystem;
  final int sizeBytes;
  final bool mounted;

  /// carries a filesystem Local Drive can use without formatting it first
  final bool usable;

  /// already registered as a library
  final bool inUse;
  final String label;
  final String model;
  final String mountPoint;
  final bool removable;
  final bool readOnly;

  String get displayName {
    if (label.isNotEmpty) return label;
    if (model.isNotEmpty) return model;
    return name;
  }

  factory DriveModel.fromJson(Map<String, dynamic> json) => DriveModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        filesystem: json['filesystem'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        mounted: json['mounted'] as bool? ?? false,
        usable: json['usable'] as bool? ?? false,
        inUse: json['in_use'] as bool? ?? false,
        label: json['label'] as String? ?? '',
        model: json['model'] as String? ?? '',
        mountPoint: json['mount_point'] as String? ?? '',
        removable: json['removable'] as bool? ?? false,
        readOnly: json['read_only'] as bool? ?? false,
      );
}

/// The detected drives list, plus whether the helper answered at all.
class DriveList {
  const DriveList({required this.drives, required this.helperAvailable});

  final List<DriveModel> drives;

  /// false on a deployment without the mount helper, which is a supported
  /// choice rather than a failure
  final bool helperAvailable;

  factory DriveList.fromJson(Map<String, dynamic> json) => DriveList(
        drives: (json['drives'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(DriveModel.fromJson)
            .toList(growable: false),
        helperAvailable: json['helper_available'] as bool? ?? false,
      );
}
