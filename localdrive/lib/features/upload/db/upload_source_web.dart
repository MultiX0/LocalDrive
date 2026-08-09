import 'dart:typed_data';

import 'upload_source.dart';

/// Stands in for the file source on the web, where there is no filesystem.
///
/// A browser never gives the app a path, so nothing can be opened by name.
/// Constructing this throws rather than returning something that fails later
/// with a confusing error.
class FileUploadSource implements UploadSource {
  FileUploadSource(this.path) {
    throw UnsupportedError(
      'a browser has no filesystem, so $path cannot be opened. '
      'Use BytesUploadSource with the picked contents instead.',
    );
  }

  final String path;

  @override
  bool get survivesRestart => false;

  @override
  Future<bool> exists() async => false;

  @override
  Future<int> length() async => 0;

  @override
  Future<Uint8List> readRange(int from, int to) async => Uint8List(0);
}

/// The contents the file picker handed over, held in memory.
///
/// This is what a browser upload runs on. It cannot survive a reload, so a
/// half-finished upload is dropped rather than left looking resumable.
class BytesUploadSource implements UploadSource {
  BytesUploadSource(this.bytes);

  final Uint8List bytes;

  @override
  bool get survivesRestart => false;

  @override
  Future<bool> exists() async => true;

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readRange(int from, int to) async =>
      Uint8List.sublistView(bytes, from, to);
}
