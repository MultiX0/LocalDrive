import 'dart:io';

import 'package:dio/dio.dart';

import '../../../imports.dart';
import '../models/release_model.dart';
import '../services/update_service.dart';

/// Where an update has got to.
///
/// Modelled as states rather than a pile of booleans because the screen has to
/// say exactly one true thing at a time, and "checking and also failed and
/// also 40 percent downloaded" is not a thing that can be rendered.
sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

/// Nothing to do. Worth saying out loud: an update button that goes quiet is
/// indistinguishable from one that is broken.
class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate(this.version);

  final String version;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);

  final ReleaseModel release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading({
    required this.release,
    required this.received,
    required this.total,
  });

  final ReleaseModel release;
  final int received;
  final int total;

  /// null while the server has not said how big the file is, so the bar can
  /// show motion rather than a fraction that would be a lie
  double? get fraction => total <= 0 ? null : received / total;
}

/// Downloaded and handed to the installer. On Windows the app is about to
/// close itself; on Android the system installer is on screen.
class UpdateInstalling extends UpdateState {
  const UpdateInstalling();
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);

  final String message;
}

/// Checks, downloads and installs, in that order, with the decision in the
/// middle belonging to whoever is using the app.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateIdle();

  UpdateService get _service => ref.read(updateServiceProvider);
  CancelToken? _cancel;

  /// Looks for a newer release.
  ///
  /// [quiet] is the check that runs by itself when the app starts. It reports
  /// an update if there is one and otherwise leaves the state alone, so a
  /// laptop that opened the app on a train does not get an error about GitHub
  /// being unreachable when nobody asked it anything.
  Future<void> check({bool quiet = false}) async {
    if (!UpdateService.canUpdateInPlace) return;
    if (!quiet) state = const UpdateChecking();

    try {
      final release = await _service.check();
      if (release != null) {
        state = UpdateAvailable(release);
        return;
      }
      if (!quiet) state = UpdateUpToDate(await _service.currentVersion());
    } on Object catch (error) {
      if (!quiet) state = UpdateFailed(_readable(error));
    }
  }

  /// Downloads the release and hands it to the platform installer.
  Future<void> install(ReleaseModel release) async {
    _cancel = CancelToken();
    state = UpdateDownloading(release: release, received: 0, total: release.size);

    try {
      final file = await _service.download(
        release,
        cancelToken: _cancel,
        onProgress: (received, total) {
          if (state is! UpdateDownloading) return;
          state = UpdateDownloading(
            release: release,
            received: received,
            total: total > 0 ? total : release.size,
          );
        },
      );

      state = const UpdateInstalling();
      await _service.install(file);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        state = UpdateAvailable(release);
        return;
      }
      state = UpdateFailed(_readable(error));
    } on Object catch (error) {
      state = UpdateFailed(_readable(error));
    } finally {
      _cancel = null;
    }
  }

  void cancel() {
    _cancel?.cancel('cancelled');
    _cancel = null;
  }

  void dismiss() => state = const UpdateIdle();

  String _readable(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 404) return 'no release file for this platform';
      if (status != null) return 'the update server answered $status';
      return 'could not reach the update server';
    }
    if (error is FileSystemException) return 'could not save the download';
    return error.toString();
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
