import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the bytes of offline available files live on this device.
///
/// One flat directory keyed by node id rather than a mirror of the server's
/// folder names. Two files in different folders can share a name, names change
/// when someone renames a file, and a name can contain characters the local
/// filesystem will not take. The id has none of those problems, and the
/// database already knows which id is which file.
class OfflineFiles {
  OfflineFiles({Directory? root}) : _root = root; // ignore: prefer_initializing_formals


  Directory? _root;

  Future<Directory> directory() async {
    if (_root != null) return _root!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'offline'));
    await dir.create(recursive: true);
    return _root = dir;
  }

  /// The path a node's bytes belong at. The extension is kept so the platform
  /// still opens the file with the right app when it is handed off.
  Future<String> pathFor(String nodeId, String name) async {
    final dir = await directory();
    final extension = p.extension(name);
    return p.join(dir.path, '$nodeId$extension');
  }

  Future<bool> exists(String path) =>
      path.isEmpty ? Future<bool>.value(false) : File(path).exists();

  Future<void> remove(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// What is actually on disk, which can drift from what the database believes
  /// if the OS reclaimed space or someone cleared the app's data.
  Future<int> bytesOnDisk() async {
    final dir = await directory();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clear() async {
    final dir = await directory();
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
  }
}
