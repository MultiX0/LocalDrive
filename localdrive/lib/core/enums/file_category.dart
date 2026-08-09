import 'package:flutter/widgets.dart';

import '../constants/ld_colors.dart';

/// The coarse grouping the server resolves and the client colors and badges
/// by. Names match the server's own constants exactly.
enum FileCategory {
  folder,
  image,
  video,
  audio,
  pdf,
  document,
  spreadsheet,
  presentation,
  archive,
  code,
  text,
  generic;

  static FileCategory fromName(String? raw) {
    return switch (raw) {
      'folder' => FileCategory.folder,
      'image' => FileCategory.image,
      'video' => FileCategory.video,
      'audio' => FileCategory.audio,
      'pdf' => FileCategory.pdf,
      'document' => FileCategory.document,
      'spreadsheet' => FileCategory.spreadsheet,
      'presentation' => FileCategory.presentation,
      'archive' => FileCategory.archive,
      'code' => FileCategory.code,
      'text' => FileCategory.text,
      _ => FileCategory.generic,
    };
  }

  /// The front panel tint of this type's layered icon.
  Color get tint => switch (this) {
        FileCategory.folder => LdColors.folderSwatches['neutral']!,
        FileCategory.image ||
        FileCategory.video ||
        FileCategory.audio =>
          LdColors.fileMedia,
        FileCategory.pdf => LdColors.filePdf,
        FileCategory.document => LdColors.fileDocument,
        FileCategory.spreadsheet => LdColors.fileSpreadsheet,
        FileCategory.presentation => LdColors.filePresentation,
        FileCategory.code => LdColors.fileCode,
        // plain text, markdown, archives and anything unrecognized are
        // deliberately colorless so the common case does not compete visually
        FileCategory.archive ||
        FileCategory.text ||
        FileCategory.generic =>
          LdColors.fileNeutral,
      };

  bool get isFolder => this == FileCategory.folder;

  /// only these render inline; everything else is a type badge plus download
  bool get previewable => switch (this) {
        FileCategory.image ||
        FileCategory.video ||
        FileCategory.audio ||
        FileCategory.pdf ||
        FileCategory.text ||
        FileCategory.code ||
        FileCategory.spreadsheet ||
        FileCategory.document ||
        FileCategory.presentation =>
          true,
        _ => false,
      };

  /// what the gallery collects. Video belongs with photos here because that is
  /// how a camera roll works: they were taken on the same day with the same
  /// device, and splitting them apart would be the app imposing a distinction
  /// nobody thinks in
  bool get isGallery =>
      this == FileCategory.image || this == FileCategory.video;

  /// these usually carry a real rendered thumbnail already
  bool get expectsThumbnail => switch (this) {
        FileCategory.image || FileCategory.video || FileCategory.pdf => true,
        _ => false,
      };
}

/// The caller's resolved role on one node, mirroring the server's matrix.
enum AccessRole {
  none,
  viewer,
  editor,
  owner;

  static AccessRole fromName(String? raw) => switch (raw) {
        'owner' => AccessRole.owner,
        'editor' => AccessRole.editor,
        'viewer' => AccessRole.viewer,
        _ => AccessRole.none,
      };

  bool get canBrowse => index >= AccessRole.viewer.index;
  bool get canStar => index >= AccessRole.viewer.index;
  bool get canCreate => index >= AccessRole.editor.index;
  bool get canRename => index >= AccessRole.editor.index;
  bool get canUploadVersion => index >= AccessRole.editor.index;
  bool get canMove => this == AccessRole.owner;
  bool get canRecolor => this == AccessRole.owner;
  bool get canTrash => this == AccessRole.owner;
  bool get canShare => this == AccessRole.owner;
}

/// How a list of nodes is ordered.
enum SortBy {
  name('name'),
  updated('updated'),
  size('size'),
  created('created'),

  /// when a picture was taken, which only the gallery has any use for. The
  /// server falls back to upload time for anything with no capture time
  taken('taken');

  const SortBy(this.wire);
  final String wire;

  static SortBy fromWire(String? raw) =>
      SortBy.values.firstWhere((s) => s.wire == raw, orElse: () => SortBy.name);
}

/// Grid or list, remembered per device.
enum ViewMode {
  grid,
  list;

  ViewMode get toggled => this == ViewMode.grid ? ViewMode.list : ViewMode.grid;
}
