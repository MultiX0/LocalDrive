import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/release_model.dart';

// Checks GitHub for a newer stable release of the client, downloads it and
// hands it to the platform installer.
//
// The check runs by itself, because nobody thinks to go looking for a version
// number. Installing never does: the app says what it found and waits. An app
// that replaces itself in the background is not something to do to a person
// holding their own files, and an app that never mentions a security fix is
// not much better.
class UpdateService {
  UpdateService({Dio? client})
      : _dio = client ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 10),
              headers: <String, String>{
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'localdrive-client',
              },
            ));

  final Dio _dio;

  static const repo = 'MultiX0/LocalDrive';
  static const _api = 'https://api.github.com/repos/$repo/releases';

  // The release file for the platform we are running on, matching the names
  // the release workflow publishes. Anything not listed updates by hand:
  // the web build is whatever the server serves, iOS comes from the App
  // Store, and macOS is not published yet.
  static String? assetFor(TargetPlatform platform) {
    if (kIsWeb) return null;
    switch (platform) {
      case TargetPlatform.android:
        return 'localdrive-client.apk';
      case TargetPlatform.windows:
        return 'localdrive-client-windows.zip';
      case TargetPlatform.linux:
        return 'localdrive-client-linux.tar.gz';
      default:
        return null;
    }
  }

  // Whether this build can update itself at all.
  //
  // The web app is whatever the server is serving, so it updates when the
  // server does and has nothing to download. iOS comes from the App Store.
  // Offering a button that cannot work is worse than offering none.
  static bool get canUpdateInPlace =>
      !kIsWeb && assetFor(defaultTargetPlatform) != null;

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  // Returns the newest stable release if it is newer than what is installed,
  // or null when there is nothing to do.
  //
  // Prereleases are skipped. Someone who wants a release candidate can fetch
  // it from the releases page; having an update button pull one silently is
  // how a person ends up testing a build they never agreed to test.
  Future<ReleaseModel?> check({String? asset}) async {
    final target = asset ?? assetFor(defaultTargetPlatform);
    if (target == null) return null;

    final current = await currentVersion();
    final response = await _dio.get<List<dynamic>>('$_api?per_page=10');
    final entries = response.data ?? const <dynamic>[];

    for (final entry in entries) {
      if (entry is! Map) continue;
      if (entry['draft'] == true || entry['prerelease'] == true) continue;

      final release = ReleaseModel.fromJson(
        Map<String, dynamic>.from(entry),
        assetName: target,
      );
      if (release.downloadUrl == null) continue;
      return release.isNewerThan(current) ? release : null;
    }
    return null;
  }

  // Downloads the release file and returns where it landed.
  //
  // It goes to the app's own directory rather than Downloads: on Android the
  // installer has to be able to read it back, and a path we own is the one
  // place that is true without asking for storage permission.
  Future<File> download(
    ReleaseModel release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url = release.downloadUrl;
    if (url == null) {
      throw StateError('this release has no file for this platform');
    }

    final dir = await getApplicationSupportDirectory();
    final into = File('${dir.path}${Platform.pathSeparator}${release.assetName}');
    if (await into.exists()) await into.delete();

    await _dio.download(
      url,
      into.path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) => onProgress?.call(received, total),
      options: Options(headers: <String, String>{'Accept': 'application/octet-stream'}),
    );
    return into;
  }

  // Hands the downloaded file to whatever installs things on this platform.
  Future<void> install(File file) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // the system installer takes it from here, including the permission
        // prompt. There is no way to install an apk without one, and there
        // should not be
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          throw StateError('the installer refused the file: ${result.message}');
        }
      case TargetPlatform.windows:
        await _installWindows(file);
      default:
        // nothing else publishes a file this can act on, so reveal it and let
        // the person do it rather than pretending to
        await OpenFilex.open(file.parent.path);
    }
  }

  // Replaces the running app on Windows.
  //
  // A program cannot overwrite its own exe while it is running, so this writes
  // a small script that waits for this process to exit, swaps the files in,
  // starts the new build and deletes itself. That is how every self updating
  // desktop app on Windows does it, because Windows offers nothing better.
  //
  // it copies into the install directory rather than deleting it first, so
  // a machine that loses power halfway through still has an app that starts.
  Future<void> _installWindows(File archive) async {
    final exe = File(Platform.resolvedExecutable);
    final installDir = exe.parent.path;

    final staging = Directory(
      '${archive.parent.path}${Platform.pathSeparator}update-staging',
    );
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    await extractFileToDisk(archive.path, staging.path);

    // a zip that contains one top level folder is unwrapped, so the copy lands
    // as the app's files rather than as a folder inside the install directory
    final root = await _archiveRoot(staging);

    final script = File(
      '${archive.parent.path}${Platform.pathSeparator}apply-update.cmd',
    );
    await script.writeAsString(
      <String>[
        '@echo off',
        'set "TARGET=$installDir"',
        'set "SOURCE=${root.path}"',
        // wait for this process to let go of its own files
        ':wait',
        'tasklist /fi "PID eq $pid" | find "$pid" >nul',
        'if not errorlevel 1 (',
        '  ping -n 2 127.0.0.1 >nul',
        '  goto wait',
        ')',
        'xcopy "%SOURCE%\\*" "%TARGET%\\" /E /Y /I >nul',
        'start "" "${exe.path}"',
        'del "%~f0"',
      ].join('\r\n'),
    );

    await Process.start(
      'cmd.exe',
      <String>['/c', script.path],
      mode: ProcessStartMode.detached,
runInShell: false,
    );

    // let go of the files the script is waiting for
    exit(0);
  }

  // The directory holding the new build, unwrapping a single top level folder.
  Future<Directory> _archiveRoot(Directory staging) async {
    final entries = await staging.list().toList();
    final dirs = entries.whereType<Directory>().toList();
    if (entries.length == 1 && dirs.length == 1) return dirs.first;
    return staging;
  }
}
