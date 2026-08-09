import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// How this device names itself when it asks to sign in. The person approving
/// it sees exactly this, so it has to be recognizable rather than a serial.
class DeviceIdentity {
  const DeviceIdentity({
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  final String name;
  final String platform;
  final String appVersion;
}

final deviceInfoProvider = FutureProvider<DeviceIdentity>((ref) async {
  final package = await PackageInfo.fromPlatform();
  final version = '${package.version}+${package.buildNumber}';
  final plugin = DeviceInfoPlugin();

  if (kIsWeb) {
    final web = await plugin.webBrowserInfo;
    final browser = web.browserName.name;
    return DeviceIdentity(
      name: '${_capitalize(browser)} on the web',
      platform: 'web',
      appVersion: version,
    );
  }

  if (Platform.isAndroid) {
    final info = await plugin.androidInfo;
    return DeviceIdentity(
      name: '${info.manufacturer} ${info.model}'.trim(),
      platform: 'android',
      appVersion: version,
    );
  }
  if (Platform.isIOS) {
    final info = await plugin.iosInfo;
    return DeviceIdentity(
      name: info.name.isNotEmpty ? info.name : info.utsname.machine,
      platform: 'ios',
      appVersion: version,
    );
  }
  if (Platform.isMacOS) {
    final info = await plugin.macOsInfo;
    return DeviceIdentity(
      name: info.computerName,
      platform: 'macos',
      appVersion: version,
    );
  }
  if (Platform.isWindows) {
    final info = await plugin.windowsInfo;
    return DeviceIdentity(
      name: info.computerName,
      platform: 'windows',
      appVersion: version,
    );
  }
  if (Platform.isLinux) {
    final info = await plugin.linuxInfo;
    return DeviceIdentity(
      name: info.prettyName,
      platform: 'linux',
      appVersion: version,
    );
  }

  return DeviceIdentity(
    name: 'Unnamed device',
    platform: 'unknown',
    appVersion: version,
  );
});

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
