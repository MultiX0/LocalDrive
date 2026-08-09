import 'dart:typed_data';

import 'package:dio/dio.dart' show Response, ResponseType;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/enums/file_category.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_exception.dart';
import '../models/node_model.dart';

/// The API surface for the node tree. Nothing above this layer builds a URL.
class FilesDb {
  const FilesDb(this._api);

  final ApiClient _api;

  Future<List<NodeModel>> list({
    String parentId = '',
    String filter = NodeFilter.none,
    String query = '',
    SortBy sortBy = SortBy.name,
    bool descending = false,
    int limit = 200,
    int offset = 0,
  }) async {
    final json = await _api.get(Api.nodes, query: <String, dynamic>{
      if (parentId.isNotEmpty) Api.qParentId: parentId,
      if (filter.isNotEmpty) Api.qFilter: filter,
      if (query.isNotEmpty) Api.qQuery: query,
      Api.qSort: sortBy.wire,
      Api.qOrder: descending ? 'desc' : 'asc',
      Api.qLimit: limit,
      Api.qOffset: offset,
    });
    return _nodes(json['nodes']);
  }

  Future<NodeModel> node(String id) async =>
      NodeModel.fromJson(await _api.get(Api.node(id)));

  /// The breadcrumb, root first.
  Future<List<NodeModel>> path(String id) async {
    final json = await _api.get(Api.nodePath(id));
    return _nodes(json['path']);
  }

  Future<NodeModel> createFolder({
    required String name,
    String parentId = '',
    String libraryId = '',
    String color = '',
    String? idempotencyKey,
  }) async =>
      NodeModel.fromJson(await _api.post(
        Api.folder,
        idempotencyKey: idempotencyKey,
        body: <String, dynamic>{
          'name': name,
          if (parentId.isNotEmpty) 'parent_id': parentId,
          if (libraryId.isNotEmpty) 'library_id': libraryId,
          if (color.isNotEmpty) 'color': color,
        },
      ));

  Future<NodeModel> rename(String id, String name) async =>
      NodeModel.fromJson(
        await _api.patch(Api.node(id), body: <String, dynamic>{'name': name}),
      );

  Future<NodeModel> move(String id, String parentId) async =>
      NodeModel.fromJson(await _api.patch(
        Api.node(id),
        body: <String, dynamic>{
          'parent_id': parentId.isEmpty ? Api.rootParent : parentId,
        },
      ));

  Future<NodeModel> recolor(String id, String color) async =>
      NodeModel.fromJson(
        await _api.patch(Api.node(id), body: <String, dynamic>{'color': color}),
      );

  Future<void> star(String id) => _api.post(Api.star(id));

  Future<void> unstar(String id) => _api.delete(Api.star(id));

  Future<NodeModel> trash(String id) async =>
      NodeModel.fromJson(await _api.delete(Api.node(id)));

  Future<NodeModel> restore(String id) async =>
      NodeModel.fromJson(await _api.post(Api.restore(id)));

  Future<void> deleteForever(String id) => _api.delete(Api.permanent(id));

  Future<List<NodeModel>> trashList({int limit = 200, int offset = 0}) async {
    final json = await _api.get(Api.trash, query: <String, dynamic>{
      Api.qLimit: limit,
      Api.qOffset: offset,
    });
    return _nodes(json['nodes']);
  }

  Future<int> trashRetentionDays() async {
    final json = await _api.get(Api.trash, query: <String, dynamic>{
      Api.qLimit: 1,
    });
    return json['retention_days'] as int? ?? 30;
  }

  /// Up to four thumbnails from a folder's own contents, for the content peek.
  Future<List<NodePreviewModel>> folderPreview(String id) async {
    final json = await _api.get(Api.preview(id));
    final list = json['previews'] as List<dynamic>? ?? const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NodePreviewModel.fromJson)
        .toList(growable: false);
  }

  Future<List<NodeVersionModel>> versions(String id) async {
    final json = await _api.get(Api.versions(id));
    final list = json['versions'] as List<dynamic>? ?? const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NodeVersionModel.fromJson)
        .toList(growable: false);
  }

  Future<NodeModel> restoreVersion(String nodeId, String versionId) async =>
      NodeModel.fromJson(
        await _api.post(Api.restoreVersion(nodeId, versionId)),
      );

  /// Absolute URLs for the widgets that fetch bytes themselves, such as an
  /// Image or a video player.
  String thumbnailUrl(String id) =>
      _api.absolute(Api.thumbnail(id), signed: true);

  String downloadUrl(String id, {bool inline = false}) => _api.absolute(
        '${Api.download(id)}${inline ? '?${Api.qInline}=1' : ''}',
        signed: true,
      );

  Map<String, String> get authHeaders => _api.authHeaders;

  /// A bounded prefix of a file, decoded as text, for the inline text and code
  /// reader.
  ///
  /// It asks for a byte range rather than the whole file, so opening a log
  /// that has grown to hundreds of megabytes costs the same as opening a small
  /// one. `truncated` is true when the server had more to give, which is what
  /// the viewer shows its notice from.
  Future<({String text, bool truncated})> textContent(
    String id, {
    int maxBytes = 512 * 1024,
  }) async {
    final response = await _api.raw<String>(
      'GET',
      '${Api.download(id)}?${Api.qInline}=1',
      headers: <String, dynamic>{'Range': 'bytes=0-${maxBytes - 1}'},
      responseType: ResponseType.plain,
    );
    final text = response.data ?? '';
    return (text: text, truncated: _wasTruncated(response, maxBytes));
  }

  /// The whole file as bytes, for a format that can only be read complete.
  ///
  /// A zip container has its index at the end, so a spreadsheet or a document
  /// cannot be parsed from a prefix the way a log file can. The cap is what
  /// keeps that from meaning "any file, however large, straight into memory":
  /// past it the viewer says the file is too big to open here rather than
  /// taking the app down trying.
  Future<Uint8List> fileBytes(
    String id, {
    int maxBytes = 24 * 1024 * 1024,
  }) async {
    final response = await _api.raw<List<int>>(
      'GET',
      '${Api.download(id)}?${Api.qInline}=1',
      responseType: ResponseType.bytes,
    );
    final bytes = response.data ?? const <int>[];
    if (bytes.length > maxBytes) {
      throw const ApiException(
        kind: ApiErrorKind.invalidRequest,
        message: 'that file is too large to open here',
        code: 'too_large_to_preview',
      );
    }
    return Uint8List.fromList(bytes);
  }

  /// Whether the range answer stopped short of the end of the file.
  ///
  /// A `Content-Range: bytes 0-511/2048` says exactly that and is believed
  /// first. A server that ignored the header and sent the whole body leaves
  /// only the length of what arrived to go on.
  static bool _wasTruncated(Response<String> response, int maxBytes) {
    final range = response.headers.value('content-range');
    if (range != null) {
      final total = int.tryParse(range.split('/').last.trim());
      final end = int.tryParse(
        range.split('/').first.trim().split('-').last.trim(),
      );
      if (total != null && end != null) return end + 1 < total;
    }
    return (response.data?.length ?? 0) >= maxBytes;
  }

  List<NodeModel> _nodes(Object? raw) {
    final list = raw as List<dynamic>? ?? const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(NodeModel.fromJson)
        .toList(growable: false);
  }
}
