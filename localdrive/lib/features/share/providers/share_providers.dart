import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/core_providers.dart';
import '../db/share_db.dart';
import '../models/share_model.dart';

export '../models/share_model.dart';

final shareDbProvider = Provider<ShareDb>((ref) {
  return ShareDb(ref.watch(apiClientProvider));
});

/// The links on one node.
final nodeSharesProvider =
    FutureProvider.autoDispose.family<List<ShareModel>, String>(
  (ref, nodeId) => ref.watch(shareDbProvider).forNode(nodeId),
);

/// Everyone one node is shared with directly.
final nodeGrantsProvider =
    FutureProvider.autoDispose.family<List<GrantModel>, String>(
  (ref, nodeId) => ref.watch(shareDbProvider).grants(nodeId),
);

/// Every account on the server, which powers the People picker.
final peopleProvider = FutureProvider.autoDispose<List<PersonModel>>((ref) {
  return ref.watch(shareDbProvider).people();
});

/// What one public link resolves to, for the screen someone lands on after
/// following it. autoDispose, because a link view is a visit and not a session.
final publicShareProvider =
    FutureProvider.autoDispose.family<PublicShareModel, String>(
  (ref, token) => ref.watch(shareDbProvider).publicShare(token),
);

/// The Shared by me screen.
final myServiceSharesProvider =
    FutureProvider.autoDispose<List<ShareModel>>((ref) {
  return ref.watch(shareDbProvider).mine();
});
