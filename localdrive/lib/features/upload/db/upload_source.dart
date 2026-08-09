import 'dart:typed_data';

export 'upload_source_io.dart'
    if (dart.library.js_interop) 'upload_source_web.dart';

/// Where an upload's bytes come from.
///
/// The queue used to take a filesystem path and open it directly, which is
/// fine everywhere except a browser: there is no path there, only the contents
/// the file picker hands over. Everything the uploader actually needs is a
/// length and a range of bytes, so that is all this promises.
abstract class UploadSource {
  /// Total size, so the tus create call can declare it up front.
  Future<int> length();

  /// The bytes in `[from, to)`.
  Future<Uint8List> readRange(int from, int to);

  /// Whether the bytes will still be there after the app restarts.
  ///
  /// True for a file on disk, false for a browser's in-memory copy. The queue
  /// uses this to decide whether a half-finished upload is worth keeping.
  bool get survivesRestart;

  /// Whether the source can still be read.
  Future<bool> exists();
}

/// Holds the sources for uploads that only live in memory.
///
/// A browser has nowhere to put a picked file, so its bytes stay here until
/// the upload finishes. Keyed by transfer id, and dropped as soon as the
/// transfer leaves the queue so a cancelled 2 GB video is not held forever.
class InMemorySources {
  InMemorySources._();
  static final InMemorySources instance = InMemorySources._();

  final Map<String, UploadSource> _byTransferId = <String, UploadSource>{};

  void put(String transferId, UploadSource source) {
    _byTransferId[transferId] = source;
  }

  UploadSource? get(String transferId) => _byTransferId[transferId];

  void drop(String transferId) {
    _byTransferId.remove(transferId);
  }

  void clear() => _byTransferId.clear();
}
