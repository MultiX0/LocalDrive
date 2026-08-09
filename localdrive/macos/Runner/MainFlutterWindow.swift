import Cocoa
import FlutterMacOS
import bitsdojo_window_macos

/// The app's window, and the macOS half of the one method channel.
///
/// It subclasses BitsdojoWindow rather than NSWindow so the app draws its own
/// title bar. macOS keeps the traffic lights; only the bar behind them belongs
/// to the app, which is the convention on this platform and not the same
/// tradeoff Windows and Linux make.
class MainFlutterWindow: BitsdojoWindow {
  private let beacon = PresenceBeacon()

  override func bitsdojo_window_configure() -> UInt {
    return BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerPlatformChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func registerPlatformChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "app.localdrive/platform",
      binaryMessenger: controller.engine.binaryMessenger
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

      // a desktop process is not killed for being off screen, so there is
      // nothing to declare to the system here
      case "startTransferService", "updateTransferProgress",
           "stopTransferService", "scheduleRetry":
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
