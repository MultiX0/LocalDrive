import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_client.dart';
import '../models/library_model.dart';

/// The API surface for libraries and drives.
class StorageDb {
  const StorageDb(this._api);

  final ApiClient _api;

  Future<LibrarySummary> libraries() async =>
      LibrarySummary.fromJson(await _api.get(Api.libraries));

  Future<DriveList> drives() async =>
      DriveList.fromJson(await _api.get(Api.drives));

  Future<void> setDefault(String libraryId) =>
      _api.patch(Api.librarySetDefault(libraryId));

  Future<void> rename(String libraryId, String name) =>
      _api.patch(Api.library(libraryId), body: <String, dynamic>{'name': name});

  Future<String> eject(String libraryId) async {
    final json = await _api.post(Api.libraryEject(libraryId));
    return json['message'] as String? ?? '';
  }

  Future<LibraryModel> mountDrive(
    String driveId, {
    String label = '',
    bool makeDefault = false,
  }) async =>
      LibraryModel.fromJson(await _api.post(
        Api.mountDrive(driveId),
        body: <String, dynamic>{
          if (label.isNotEmpty) 'label': label,
          'make_default': makeDefault,
        },
      ));

  /// The one destructive action in the storage flow. The phrase is checked
  /// here, again by the server, and once more by the helper.
  Future<void> formatDrive(
    String driveId, {
    required String confirmation,
    String filesystem = 'ext4',
    String label = '',
  }) =>
      _api.post(Api.formatDrive(driveId), body: <String, dynamic>{
        'confirmation': confirmation,
        'filesystem': filesystem,
        if (label.isNotEmpty) 'label': label,
      });

  Future<LibraryModel> pool({
    required String name,
    required List<String> libraryIds,
    bool makeDefault = false,
  }) async =>
      LibraryModel.fromJson(await _api.post(
        Api.poolDrives,
        body: <String, dynamic>{
          'name': name,
          'library_ids': libraryIds,
          'make_default': makeDefault,
        },
      ));
}
