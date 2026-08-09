import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A download's bytes in a browser tab.
///
/// A tab cannot write to disk as bytes arrive, so the file is assembled in
/// memory and handed to the browser as a blob at the end, which is the point
/// where the browser's own download UI takes over. That also means there is
/// nothing to resume from: a browser download that was interrupted starts
/// again, and `supportsResume` says so rather than letting the transfer engine
/// send a Range header that would quietly produce a corrupt file.
class DownloadSink {
  DownloadSink._(this._filename);

  final String _filename;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  int get resumeAt => 0;

  static bool get supportsResume => false;

  static Future<DownloadSink> open(String filename) async =>
      DownloadSink._(filename);

  /// A tab has no filesystem to write a chosen path into. Offline availability
  /// is therefore not offered on web, and this exists only so both sides of
  /// the conditional import present the same surface.
  static Future<DownloadSink> openAt(String absolutePath) async =>
      throw UnsupportedError(
        'a browser tab cannot write to a path on this device',
      );

  Future<void> write(List<int> chunk) async => _buffer.add(chunk);

  /// Hands the assembled bytes to the browser. The returned string is the file
  /// name rather than a path, because in a tab there is no path to give.
  Future<String> finish() async {
    final bytes = _buffer.takeBytes();
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = _filename
      ..style.display = 'none';
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();

    // the object URL holds the whole file alive until it is released
    web.URL.revokeObjectURL(url);
    return _filename;
  }

  Future<void> close() async => _buffer.clear();

  Future<void> discard() async => _buffer.clear();
}
