import Foundation

/// Values shared by the app and the packet tunnel extension.
/// If you change bundle identifiers in project.yml, update them here too.
enum AppConfig {
    static let appGroup = "group.com.example.netlens"
    static let tunnelBundleID = "com.example.netlens.PacketTunnel"

    /// Address assigned to the virtual interface.
    static let tunnelAddress = "10.111.222.1"
    /// Fake DNS server the system is told to use. Only this single /32 is routed
    /// into the tunnel, so all other traffic keeps flowing normally.
    static let interceptDNSAddress = "10.111.222.53"
    /// Real resolvers the extension forwards lookups to.
    static let upstreamDNS = ["1.1.1.1", "8.8.8.8"]

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.temporaryDirectory
    }

    static var eventLogURL: URL {
        containerURL.appendingPathComponent("dns-events.ndjson")
    }
}
