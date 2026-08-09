import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Finds servers by asking, rather than by listening for an announcement.
///
/// mDNS is the obvious mechanism and it is not reliable enough on its own.
/// Windows runs its own responder holding the mDNS port, so a server there
/// publishes a record that nothing ever answers, and from here that is
/// indistinguishable from an empty network. Docker has its own version of the
/// same problem.
///
/// This sends one small packet to the broadcast address instead. Every Local
/// Drive server that hears it replies with how to reach it. There is no
/// multicast group to join and no responder to compete with, so it behaves the
/// same on a wired network, on wifi, and on a phone's hotspot.
class BeaconProbe {
  /// Matches the server's BeaconPort: the same number as the http port, one
  /// being udp and the other tcp.
  static const int port = 7443;

  static const String _probe = 'LOCALDRIVE-PROBE/1';
  static const String _replyMagic = 'LOCALDRIVE-HELLO/1';

  /// Broadcasts a probe and yields each distinct server that answers.
  ///
  /// Results arrive as they come rather than after the full wait, so a server
  /// on the same machine shows up immediately while the network is still being
  /// asked.
  Stream<BeaconResult> search({
    Duration timeout = const Duration(seconds: 3),
  }) async* {
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      // no socket, no discovery. The address field is always there.
      return;
    }
    socket.broadcastEnabled = true;

    final controller = StreamController<BeaconResult>();
    final seen = <String>{};

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final result = _parse(datagram);
      if (result == null) return;
      // one server answers on several interfaces, and it is one server
      if (!seen.add(result.serverId.isEmpty ? result.host : result.serverId)) {
        return;
      }
      if (!controller.isClosed) controller.add(result);
    });

    final payload = utf8.encode(_probe);
    for (final target in await _targets()) {
      try {
        socket.send(payload, target, port);
      } on SocketException {
        // one unusable interface should not stop the others
      }
    }

    final timer = Timer(timeout, () {
      socket.close();
      if (!controller.isClosed) controller.close();
    });

    try {
      yield* controller.stream;
    } finally {
      timer.cancel();
      socket.close();
      if (!controller.isClosed) await controller.close();
    }
  }

  BeaconResult? _parse(Datagram datagram) {
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['magic'] != _replyMagic) return null;
      return BeaconResult(
        host: datagram.address.address,
        serverId: decoded['server_id'] as String? ?? '',
        name: decoded['name'] as String? ?? 'Local Drive',
        version: decoded['version'] as String? ?? '',
        port: (decoded['port'] as num?)?.toInt() ?? port,
        tls: decoded['tls'] as bool? ?? false,
        ready: decoded['ready'] as bool? ?? false,
      );
    } on Object {
      // anything else on the port is not ours
      return null;
    }
  }

  /// Where to send the probe.
  ///
  /// The global broadcast address is refused on some networks, and a hotspot
  /// often puts the phone on a different subnet from the one the global
  /// address reaches. Sending to each interface's own broadcast address as
  /// well covers both, and duplicates are dropped by server id.
  Future<List<InternetAddress>> _targets() async {
    final targets = <InternetAddress>[
      InternetAddress('255.255.255.255'),
      InternetAddress('127.0.0.1'),
    ];

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final broadcast = _broadcastOf(address.address);
          if (broadcast != null) targets.add(InternetAddress(broadcast));
        }
      }
    } on Object {
      // listing interfaces is not permitted everywhere; the global address
      // alone still works on an ordinary network
    }
    return targets;
  }

  /// The /24 broadcast address for an IPv4 address.
  ///
  /// Assuming a 24 bit prefix rather than reading the real netmask, because
  /// Dart does not expose one and home networks are /24 almost without
  /// exception. A wrong guess costs one ignored packet.
  String? _broadcastOf(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }
}

/// One server that answered a probe.
class BeaconResult {
  const BeaconResult({
    required this.host,
    required this.serverId,
    required this.name,
    required this.version,
    required this.port,
    required this.tls,
    required this.ready,
  });

  final String host;
  final String serverId;
  final String name;
  final String version;
  final int port;
  final bool tls;
  final bool ready;

  String get url {
    final scheme = tls ? 'https' : 'http';
    final defaultPort = tls ? 443 : 80;
    final suffix = port == defaultPort ? '' : ':$port';
    return '$scheme://$host$suffix';
  }
}
