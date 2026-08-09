import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A download's bytes on their way to disk.
///
/// Bytes land in a `.part` file next to the final name and are only renamed
/// into place once the whole file has arrived. A killed app therefore leaves a
/// visible partial, never a file that looks complete and is not, and the next
/// run resumes from exactly the byte the partial ends at.
class DownloadSink {
  DownloadSink._(
    this._handle,
    this._partPath,
    this._finalPath,
    this.resumeAt, {
    bool exact = false,
    // ignore: prefer_initializing_formals
  }) : _exact = exact;

  final RandomAccessFile _handle;
  final String _partPath;
  final String _finalPath;

  /// true when the caller named the exact destination, which means replacing
  /// what is there rather than writing a numbered second copy beside it
  final bool _exact;

  /// how many bytes are already on disk, which is the Range offset to ask for
  final int resumeAt;

  /// True where a partial file can be resumed. It is what tells the transfer
  /// engine whether asking for a byte range is worth doing at all.
  static bool get supportsResume => true;

  /// Opens at an exact path chosen by the caller, for offline availability,
  /// which keeps its bytes in the app's own directory rather than wherever
  /// this platform puts downloads. Same `.part` and rename discipline.
  static Future<DownloadSink> openAt(String absolutePath) async {
    await Directory(p.dirname(absolutePath)).create(recursive: true);
    final partPath = '$absolutePath.part';
    final part = File(partPath);
    final existing = await part.exists() ? await part.length() : 0;
    final handle = await part.open(mode: FileMode.writeOnlyAppend);
    return DownloadSink._(handle, partPath, absolutePath, existing, exact: true);
  }

  static Future<DownloadSink> open(String filename) async {
    final directory = await _destination();
    await directory.create(recursive: true);

    final finalPath = p.join(directory.path, _sanitize(filename));
    final partPath = '$finalPath.part';
    final part = File(partPath);
    final existing = await part.exists() ? await part.length() : 0;

    final handle = await part.open(mode: FileMode.writeOnlyAppend);
    return DownloadSink._(handle, partPath, finalPath, existing);
  }

  Future<void> write(List<int> chunk) => _handle.writeFrom(chunk);

  /// Closes the file and moves it into place. Returns where it ended up, which
  /// is what the completion notice shows.
  Future<String> finish() async {
    await _handle.flush();
    await _handle.close();

    // never silently overwrite: a second copy of the same name gets a suffix,
    // the way a browser would do it. An exact destination is exempt, because
    // the caller asked for that path specifically and a refreshed offline copy
    // is meant to replace the stale one
    var target = _finalPath;
    if (_exact) {
      final existing = File(target);
      if (await existing.exists()) await existing.delete();
      await File(_partPath).rename(target);
      return target;
    }

    var counter = 1;
    while (await File(target).exists()) {
      final extension = p.extension(_finalPath);
      final stem = p.withoutExtension(_finalPath);
      target = '$stem ($counter)$extension';
      counter++;
    }

    await File(_partPath).rename(target);
    return target;
  }

  /// Leaves the partial in place. A cancelled or failed download is resumable,
  /// so throwing the bytes away would be the wrong move.
  Future<void> close() async {
    await _handle.flush();
    await _handle.close();
  }

  /// Removes the partial as well, for a transfer the person actually deleted.
  Future<void> discard() async {
    await close();
    final part = File(_partPath);
    if (await part.exists()) await part.delete();
  }

  /// The platform's own idea of where downloads go, falling back to the app's
  /// documents directory on the platforms that have no such folder.
  static Future<Directory> _destination() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final documents = await getApplicationDocumentsDirectory();
      return Directory(p.join(documents.path, 'Local Drive'));
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return Directory(p.join(downloads.path, 'Local Drive'));
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'Local Drive'));
  }

  /// A server can hold names a local filesystem will not take. Separators are
  /// the dangerous ones, since a name containing one would write outside the
  /// destination folder entirely.
  static String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    final trimmed = cleaned.trim();
    return trimmed.isEmpty ? 'download' : trimmed;
  }
}
