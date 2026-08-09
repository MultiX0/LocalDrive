import Cocoa
import FlutterMacOS

/// The macOS entry point.
///
/// Closing the window is not quitting: a transfer halfway through has no reason
/// to die because someone clicked the close button, so the app stays running in
/// the tray and quit is a deliberate choice from the tray menu.
@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// "Open With, Local Drive" from Finder, and a localdrive:// link.
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "app.localdrive/platform",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.invokeMethod("openFiles", arguments: filenames)
    sender.reply(toOpenOrPrint: .success)
  }
}
