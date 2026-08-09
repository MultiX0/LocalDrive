import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'upload_source.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_exception.dart';

/// A tus client, kept small and owned here rather than pulled in, so the
/// resume logic and the auth header stay under this app's control.
///
/// Resumability goes to the byte: a retry asks the server what it already has
/// with HEAD, then continues from exactly there, which matters far more for a
/// large video than the queue level retry policy does.
class TusUploader {
  TusUploader(this._api);

  final ApiClient _api;

  static const String _version = '1.0.0';

  /// Creates the upload and returns its url. The server refuses here, before a
  /// single byte is accepted, if the destination or the quota says no.
  Future<String> create({
    required String filename,
    required int length,
    String parentId = '',
    String nodeId = '',
    String mimeType = '',
  }) async {
    final metadata = <String>[
      'filename ${base64.encode(utf8.encode(filename))}',
      'filetype ${base64.encode(utf8.encode(mimeType))}',
      if (parentId.isNotEmpty)
        'parent_id ${base64.encode(utf8.encode(parentId))}',
      if (nodeId.isNotEmpty) 'node_id ${base64.encode(utf8.encode(nodeId))}',
    ].join(',');

    final response = await _api.raw<void>(
      'POST',
      Api.uploads,
      headers: <String, dynamic>{
        'Tus-Resumable': _version,
        'Upload-Length': '$length',
        'Upload-Metadata': metadata,
      },
    );

    final location = response.headers.value('location');
    if (location == null || location.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'the server did not return an upload location',
      );
    }
    return location;
  }

  /// Asks how much the server already holds, which is what a resume starts
  /// from.
  Future<int> offset(String uploadUrl) async {
    final response = await _api.raw<void>(
      'HEAD',
      _pathOf(uploadUrl),
      headers: <String, dynamic>{'Tus-Resumable': _version},
    );
    return int.tryParse(response.headers.value('upload-offset') ?? '') ?? 0;
  }

  /// Sends one chunk and returns the new offset plus the node id once the
  /// upload completes.
  Future<({int offset, String? nodeId})> sendChunk({
    required String uploadUrl,
    required UploadSource source,
    required int from,
    required int chunkSize,
    CancelToken? cancelToken,
    void Function(int sent)? onProgress,
  }) async {
    final total = await source.length();
    final end = math.min(from + chunkSize, total);
    final bytes = await source.readRange(from, end);

    final response = await _api.raw<void>(
      'PATCH',
      _pathOf(uploadUrl),
      body: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
      cancelToken: cancelToken,
      headers: <String, dynamic>{
        'Tus-Resumable': _version,
        'Upload-Offset': '$from',
        'Content-Type': 'application/offset+octet-stream',
        'Content-Length': '${bytes.length}',
      },
    );

    onProgress?.call(bytes.length);
    final next =
        int.tryParse(response.headers.value('upload-offset') ?? '') ?? end;
    return (
      offset: next,
      nodeId: response.headers.value(Api.headerNodeId.toLowerCase()),
    );
  }

  /// Cancels an upload and lets the server release its staging bytes.
  Future<void> terminate(String uploadUrl) async {
    try {
      await _api.raw<void>(
        'DELETE',
        _pathOf(uploadUrl),
        headers: <String, dynamic>{'Tus-Resumable': _version},
      );
    } on ApiException {
      // the sweep removes an abandoned upload after seven days anyway
    }
  }

  /// The queue stores whatever Location the server returned; this reduces it
  /// to a path the client can send again against the current node.
  String _pathOf(String uploadUrl) {
    if (!uploadUrl.startsWith('http')) return uploadUrl;
    final uri = Uri.parse(uploadUrl);
    return uri.path;
  }

}

/// The chunk size the queue sends in. Small enough that a dropped connection
/// costs little, large enough that a big file is not thousands of requests.
const int tusChunkBytes = TransferLimits.chunkBytes;
