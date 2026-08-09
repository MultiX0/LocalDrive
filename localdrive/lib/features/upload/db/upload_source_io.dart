import 'dart:io';
import 'dart:typed_data';

import 'upload_source.dart';

/// Reads from a real file, a range at a time.
///
/// Opening per chunk rather than holding a handle for the whole upload: an
/// upload can sit paused for hours, and a held handle keeps the file locked on
/// Windows and counts against the descriptor limit on everything else.
class FileUploadSource implements UploadSource {
  FileUploadSource(this.path) : _file = File(path);

  final String path;
  final File _file;

  @override
  bool get survivesRestart => true;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<int> length() => _file.length();

  @override
  Future<Uint8List> readRange(int from, int to) async {
    final handle = await _file.open();
    try {
      await handle.setPosition(from);
      return await handle.read(to - from);
    } finally {
      await handle.close();
    }
  }
}

/// Bytes already in memory. Used on desktop and mobile only when something
/// hands over contents rather than a path, such as a share intent.
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
