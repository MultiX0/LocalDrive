/// Where a download's bytes go, which is a genuinely different thing on a
/// device with a filesystem and in a browser tab that has none.
///
/// Consumers import this file and never the two behind it. The conditional
/// export means a web build never compiles the `dart:io` version and a device
/// build never compiles the browser one, so neither has to pretend to support
/// the other's model at runtime.
library;

export 'download_sink_io.dart'
    if (dart.library.js_interop) 'download_sink_web.dart';
