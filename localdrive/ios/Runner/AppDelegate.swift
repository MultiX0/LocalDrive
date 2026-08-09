import Flutter
import UIKit

/// The iOS entry point, and the iOS half of the one method channel.
///
/// Only two things live here. Background transfers on iOS are handled by a
/// background URLSession the transfer plugins already own, and everything else
/// the app needs is available in Dart, so this stays small on purpose.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let beacon = PresenceBeacon()
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // the messenger through a registrar, which is the documented way to reach
    // it without holding the engine directly
    guard let registrar = engineBridge.pluginRegistry
      .registrar(forPlugin: "LocalDrivePlatform")
    else { return }

    let channel = FlutterMethodChannel(
      name: "app.localdrive/platform",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      let arguments = call.arguments as? [String: Any] ?? [:]

      switch call.method {
      case "startPresence":
        self.beacon.start(
          displayName: arguments["name"] as? String ?? "",
          userId: arguments["userId"] as? String ?? "",
          avatarSeed: arguments["avatarSeed"] as? String ?? ""
        )
        result(true)

      case "stopPresence":
        self.beacon.stop()
        result(true)

      // there is no foreground service to run on iOS. A background
      // URLSession covers what this platform allows, and the queue resumes
      // from its last acknowledged byte on next open past that
      case "startTransferService", "updateTransferProgress",
           "stopTransferService", "scheduleRetry":
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// The beacon never outlives a visible screen.
  override func applicationDidEnterBackground(_ application: UIApplication) {
    beacon.stop()
    super.applicationDidEnterBackground(application)
  }

  /// A link that arrived while the app was already running.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    channel?.invokeMethod("deepLink", arguments: url.absoluteString)
    return super.application(app, open: url, options: options)
  }
}
