import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// The iOS Share Extension.
///
/// Appearing in the iOS share sheet needs a real second target; unlike Android
/// there is no manifest entry that does it. This is that target's whole
/// implementation.
///
/// An extension runs in its own process with its own container, so it cannot
/// hand a file to the app directly. Instead it copies what it was given into
/// the shared app group container, writes a small manifest naming what it
/// copied, and opens the app through the custom scheme. The app reads the
/// manifest on launch and enqueues real uploads from it, which means a share
/// that arrives while the app is closed is not lost.
class ShareViewController: UIViewController {

    /// Must match the app group in both targets' entitlements.
    private static let appGroup = "group.app.localdrive"

    /// Where copied files land inside the group container.
    private static let inboxName = "share-inbox"

    /// The manifest the app looks for on launch.
    private static let manifestName = "pending-share.json"

    override func viewDidLoad() {
        super.viewDidLoad()
        handleShare()
    }

    private func handleShare() {
        guard
            let items = extensionContext?.inputItems as? [NSExtensionItem],
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroup
            )
        else {
            finish()
            return
        }

        let inbox = container.appendingPathComponent(Self.inboxName, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: inbox,
            withIntermediateDirectories: true
        )

        var copied: [String] = []
        let group = DispatchGroup()

        for item in items {
            for provider in item.attachments ?? [] {
                guard provider.hasItemConformingToTypeIdentifier(UTType.item.identifier)
                else { continue }

                group.enter()
                provider.loadFileRepresentation(
                    forTypeIdentifier: UTType.item.identifier
                ) { url, _ in
                    defer { group.leave() }
                    guard let url else { return }

                    // the URL handed over is only valid inside this callback,
                    // so the bytes are copied rather than the path remembered
                    let destination = inbox.appendingPathComponent(
                        "\(UUID().uuidString)-\(url.lastPathComponent)"
                    )
                    do {
                        try FileManager.default.copyItem(at: url, to: destination)
                        copied.append(destination.path)
                    } catch {
                        // one file failing must not lose the rest of the share
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.writeManifest(container: container, paths: copied)
            self?.openApp()
            self?.finish()
        }
    }

    private func writeManifest(container: URL, paths: [String]) {
        guard !paths.isEmpty else { return }
        let manifest: [String: Any] = [
            "paths": paths,
            "received_at": Int(Date().timeIntervalSince1970 * 1000),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: manifest)
        else { return }
        try? data.write(
            to: container.appendingPathComponent(Self.manifestName),
            options: .atomic
        )
    }

    /// Brings the app forward through its own scheme. An extension cannot call
    /// UIApplication.shared.open, so this walks the responder chain to find an
    /// application object that can, which is the documented way round it.
    private func openApp() {
        guard let url = URL(string: "localdrive://share") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
