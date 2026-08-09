import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../../core/constants/storage_keys.dart';
import '../db/beacon_probe.dart';

/// A Local Drive node found on the local network.
class DiscoveredNode {
  const DiscoveredNode({
    required this.name,
    required this.host,
    required this.port,
    this.serverId = '',
    this.version = '',
    this.tls = false,
    this.ready = false,
  });

  final String name;
  final String host;
  final int port;
  final String serverId;
  final String version;
  final bool tls;

  /// whether the node has usable storage configured yet, which is what the
  /// ready or needs-setup indicator shows
  final bool ready;

  String get url {
    final scheme = tls ? 'https' : 'http';
    final defaultPort = tls ? 443 : 80;
    final suffix = port == defaultPort ? '' : ':$port';
    return '$scheme://$host$suffix';
  }
}

/// The service type the server advertises itself as.
const String kLocalDriveService = '_localdrive._tcp';

/// Browses the network for a few seconds, yielding results as they arrive
/// rather than waiting for the whole scan.
///
/// Finding nothing is a legitimate outcome, not an error: a different subnet,
/// discovery turned off on that server, or a firewall in the way all look the
/// same from here, and the manual address field is always available alongside.
final discoveryProvider =
    StreamProvider.autoDispose<List<DiscoveredNode>>((ref) async* {
  // a browser sandbox has no multicast, so the web build goes straight to the
  // manual field rather than pretending to scan
  if (kIsWeb || !(Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows ||
      Platform.isLinux)) {
    // a browser sandbox has no multicast, but the radar still sweeps once so
    // the step does not flash past before anyone can read it
    await Future<void>.delayed(AppDurations.lanScanMinimum);
    yield const <DiscoveredNode>[];
    return;
  }

  final found = <String, DiscoveredNode>{};
  final client = MDnsClient();
  ref.onDispose(client.stop);

  // the radar sweeps for a moment even when the answer arrives instantly
  final floor = Future<void>.delayed(AppDurations.lanScanMinimum);

  // The beacon runs first and alongside mDNS, because it is the one that
  // answers everywhere. mDNS fails silently when the host has its own
  // responder on the port, which Windows does, so relying on it alone means an
  // empty list next to a server that is running perfectly well.
  await for (final result in BeaconProbe().search(timeout: AppDurations.lanScan)) {
    final key = result.serverId.isEmpty ? result.url : result.serverId;
    found[key] = DiscoveredNode(
      name: result.name,
      host: result.host,
      port: result.port,
      serverId: result.serverId,
      version: result.version,
      tls: result.tls,
      ready: result.ready,
    );
    yield found.values.toList(growable: false);
  }

  try {
    await client.start();
    final deadline = DateTime.now().add(AppDurations.lanScan);

    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(kLocalDriveService),
    )) {
      if (DateTime.now().isAfter(deadline)) break;

      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        final txtRecords = <String, String>{};
        await for (final txt in client.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(ptr.domainName),
        )) {
          for (final line in txt.text.split('\n')) {
            final index = line.indexOf('=');
            if (index <= 0) continue;
            txtRecords[line.substring(0, index)] = line.substring(index + 1);
          }
        }

        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )) {
          final node = DiscoveredNode(
            name: txtRecords['name'] ??
                ptr.domainName.split('.').first.replaceAll('-', ' '),
            host: ip.address.address,
            port: srv.port,
            serverId: txtRecords['id'] ?? '',
            version: txtRecords['version'] ?? '',
            tls: txtRecords['tls'] == 'true',
            ready: txtRecords['ready'] == 'true',
          );
          found[node.url] = node;
          yield found.values.toList(growable: false);
          break;
        }
        break;
      }
    }
  } on Object {
    // discovery failing is never an error state; the manual field is right
    // there and works exactly the same
  } finally {
    client.stop();
  }

  await floor;
  yield found.values.toList(growable: false);
});
