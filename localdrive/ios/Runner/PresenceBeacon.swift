import Foundation

/// "This person, on this network, right now."
///
/// Advertised over Bonjour while a sharing screen is open, and never
/// otherwise. Broadcasting presence at all times is not something an app should
/// do without asking, and it costs battery for nothing the rest of the time.
///
/// This changes discovery and presentation only. The share itself is still a
/// permission grant against the server, so the person on the other end gets an
/// ongoing shared item they can open next week from a different device, rather
/// than a one-off copy beamed between two phones.
final class PresenceBeacon: NSObject, NetServiceDelegate {

    static let serviceType = "_ldpeer._tcp"

    /// Nothing listens on it. Bonjour requires a port, and this beacon is
    /// presence only: the actual share goes through the server, so there is no
    /// socket for anyone to connect to here.
    private static let presencePort: Int32 = 7444

    private var service: NetService?

    func start(displayName: String, userId: String, avatarSeed: String) {
        stop()

        // the instance name is what other devices see before they resolve the
        // record, so it carries nothing private
        let instance = "ld-" + String(userId.prefix(8))
        let service = NetService(
            domain: "local.",
            type: Self.serviceType,
            name: instance,
            port: Self.presencePort
        )

        let record: [String: Data] = [
            "name": Data(displayName.utf8),
            "uid": Data(userId.utf8),
            "seed": Data(avatarSeed.utf8),
        ]
        service.setTXTRecordData(NetService.data(fromTXTRecord: record))
        service.delegate = self
        service.publish()

        self.service = service
    }

    func stop() {
        service?.stop()
        service?.delegate = nil
        service = nil
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        // usually the Local Network permission being declined. Nothing to
        // recover: the picker falls back to its plain list, which works
        stop()
    }
}
