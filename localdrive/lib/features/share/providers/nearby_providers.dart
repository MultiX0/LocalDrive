import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/services/core_providers.dart';
import '../../auth/controller/session_controller.dart';

/// The service type a Local Drive app advertises itself as while a sharing
/// screen is open. Deliberately not the server's own `_localdrive._tcp`: this
/// is a person on a device, not a node.
const String kPeerService = '_ldpeer._tcp';

/// Whether this platform can see who is nearby at all.
///
/// A browser sandbox grants no raw multicast, so the web app always uses the
/// plain picker. That is correct behaviour rather than a gap, the same way
/// AirDrop has no browser equivalent.
bool get nearbySupported =>
    !kIsWeb &&
    (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux);

/// Whether this platform can announce itself, as opposed to only listening.
///
/// Android and Apple have a system service discovery API to publish through.
/// Windows and Linux have no equivalent, so on those two the picker sees other
/// people but other people do not see it. Half of a feature that works is
/// better than none, and saying so is better than implying otherwise.
bool get nearbyAdvertises =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

/// One person seen on this network right now.
class NearbyPeer {
  const NearbyPeer({required this.userId, required this.name, this.seed = ''});

  final String userId;
  final String name;
  final String seed;
}

/// Whether this device is allowed to look at the local network yet.
///
/// Everywhere except iOS there is nothing to ask, so this is true from the
/// start. iOS shows a system prompt the first time anything touches multicast,
/// and a cold prompt with no explanation is how apps end up permanently
/// denied, so there the answer waits until the sheet has explained itself.
class NearbyPermission extends Notifier<bool> {
  @override
  bool build() {
    if (!nearbySupported) return false;
    if (!Platform.isIOS) return true;
    unawaited(_restore());
    return false;
  }

  Future<void> _restore() async {
    final asked = await ref
        .read(secureStoreProvider)
        .readBool(StorageKeys.localNetworkAsked);
    if (asked) state = true;
  }

  /// Records that the explanation has been shown and the person said yes. The
  /// system prompt appears immediately afterwards, when discovery starts.
  Future<void> allow() async {
    await ref
        .read(secureStoreProvider)
        .writeBool(StorageKeys.localNetworkAsked, true);
    state = true;
  }

  /// A no is a real answer. It is not re-asked, and the picker keeps working
  /// as the plain list it always was.
  Future<void> decline() async {
    await ref
        .read(secureStoreProvider)
        .writeBool(StorageKeys.localNetworkAsked, true);
    state = false;
  }

  /// Whether the explanation still needs showing at all.
  Future<bool> needsExplaining() async {
    if (!nearbySupported || !Platform.isIOS) return false;
    return !await ref
        .read(secureStoreProvider)
        .readBool(StorageKeys.localNetworkAsked);
  }
}

final nearbyPermissionProvider =
    NotifierProvider<NearbyPermission, bool>(NearbyPermission.new);

/// Who is on this network, refreshed while the provider is alive.
///
/// autoDispose is the whole design: the beacon only advertises and only
/// listens while a sharing screen is actually open. Announcing your presence
/// at all times is not something an app should do without asking, and it would
/// cost battery for nothing the rest of the time.
final nearbyPeersProvider =
    StreamProvider.autoDispose<Map<String, NearbyPeer>>((ref) async* {
  if (!nearbySupported || !ref.watch(nearbyPermissionProvider)) {
    yield const <String, NearbyPeer>{};
    return;
  }

  // announce, if this platform can
  final platform = ref.watch(platformServiceProvider);
  final user = ref.watch(sessionProvider).user;
  if (nearbyAdvertises && user != null) {
    unawaited(
      platform.startPresence(
        name: user.displayName,
        userId: user.id,
        avatarSeed: user.avatarSeed,
      ),
    );
    ref.onDispose(() => unawaited(platform.stopPresence()));
  }

  final peers = <String, NearbyPeer>{};
  final client = MDnsClient();
  var stopped = false;
  ref.onDispose(() {
    stopped = true;
    client.stop();
  });

  try {
    await client.start();
  } on Object {
    // no multicast on this network, or the permission was declined. The plain
    // picker is right there and is fully functional
    yield const <String, NearbyPeer>{};
    return;
  }

  // one sweep, then repeat: someone can walk into the room after the sheet
  // opened, and a picker that only looked once would never notice
  while (!stopped) {
    try {
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(kPeerService),
      )) {
        if (stopped) return;
        final peer = await _resolve(client, ptr.domainName, user?.id ?? '');
        if (peer == null) continue;
        peers[peer.userId] = peer;
        yield Map<String, NearbyPeer>.unmodifiable(peers);
      }
    } on Object {
      // a failed sweep is not an error state; the next one may find someone
    }
    if (stopped) return;
    yield Map<String, NearbyPeer>.unmodifiable(peers);
    await Future<void>.delayed(const Duration(seconds: 6));
  }
});

/// Reads one peer's TXT record. Returns null for our own beacon, since seeing
/// yourself in the list of people to share with helps nobody.
Future<NearbyPeer?> _resolve(
  MDnsClient client,
  String domain,
  String ownUserId,
) async {
  await for (final txt in client.lookup<TxtResourceRecord>(
    ResourceRecordQuery.text(domain),
  )) {
    final fields = <String, String>{};
    for (final line in txt.text.split('\n')) {
      final index = line.indexOf('=');
      if (index <= 0) continue;
      fields[line.substring(0, index)] = line.substring(index + 1);
    }

    final userId = fields['uid'] ?? '';
    if (userId.isEmpty || userId == ownUserId) return null;
    return NearbyPeer(
      userId: userId,
      name: fields['name'] ?? '',
      seed: fields['seed'] ?? '',
    );
  }
  return null;
}

/// The ids of everyone currently nearby, which is all the people picker needs
/// in order to sort them up and mark them live.
final nearbyIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  return ref.watch(nearbyPeersProvider).maybeWhen(
        data: (peers) => peers.keys.toSet(),
        orElse: () => const <String>{},
      );
});
