import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/core_providers.dart';
import '../db/storage_db.dart';
import '../models/library_model.dart';

export '../models/library_model.dart';

final storageDbProvider = Provider<StorageDb>((ref) {
  return StorageDb(ref.watch(apiClientProvider));
});

/// Every library with its live disk numbers. Kept alive because the new
/// folder sheet and the storage screen both read it.
final librariesProvider = FutureProvider<LibrarySummary>((ref) {
  return ref.watch(storageDbProvider).libraries();
});

/// Detected block devices. Admin only, and it degrades to an empty list with
/// helper_available false rather than failing on a deployment without the
/// mount helper.
final drivesProvider = FutureProvider.autoDispose<DriveList>((ref) {
  return ref.watch(storageDbProvider).drives();
});

/// Any library whose backing drive is not connected, which is what the
/// persistent banner shows instead of per-file errors.
final offlineLibrariesProvider = Provider<List<LibraryModel>>((ref) {
  return ref.watch(librariesProvider).maybeWhen(
        data: (summary) => summary.offline.toList(growable: false),
        orElse: () => const <LibraryModel>[],
      );
});
