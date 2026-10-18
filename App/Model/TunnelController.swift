import Foundation
import NetworkExtension

/// Installs, starts and stops the on-device DNS monitor (packet tunnel).
@MainActor
final class TunnelController: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var onDemandEnabled = false
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    var isActive: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }

    init() {
        // The Lite edition has no tunnel extension or VPN entitlement.
        guard Edition.hasDNSMonitor else { return }
        Task { await load() }
    }

    func load() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let existing = managers.first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == AppConfig.tunnelBundleID
            }
            let manager = existing ?? Self.makeManager()
            self.manager = manager
            status = manager.connection.status
            onDemandEnabled = manager.isOnDemandEnabled
            observe(manager)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func start() async {
        if manager == nil { await load() }
        guard let manager else { return }
        do {
            manager.isEnabled = true
            try await manager.saveToPreferences()
            // Reload after saving, otherwise the first start after install can fail.
            try await manager.loadFromPreferences()
            try manager.connection.startVPNTunnel()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() async {
        guard let manager else { return }
        // On-demand would immediately reconnect, so turn it off first.
        if manager.isOnDemandEnabled {
            await setOnDemand(false)
        }
        manager.connection.stopVPNTunnel()
    }

    func setOnDemand(_ enabled: Bool) async {
        guard let manager else { return }
        manager.isEnabled = true
        manager.isOnDemandEnabled = enabled
        manager.onDemandRules = enabled ? [NEOnDemandRuleConnect()] : []
        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            onDemandEnabled = enabled
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func makeManager() -> NETunnelProviderManager {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConfig.tunnelBundleID
        proto.serverAddress = "On-device"
        let manager = NETunnelProviderManager()
        manager.protocolConfiguration = proto
        manager.localizedDescription = "NetLens DNS Monitor"
        manager.isEnabled = true
        return manager
    }

    private func observe(_ manager: NETunnelProviderManager) {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.status = manager.connection.status
            }
        }
    }
}

extension NEVPNStatus {
    var label: String {
        switch self {
        case .invalid: return "Not installed"
        case .disconnected: return "Off"
        case .connecting: return "Starting…"
        case .connected: return "Monitoring"
        case .reasserting: return "Reconnecting…"
        case .disconnecting: return "Stopping…"
        @unknown default: return "Unknown"
        }
    }
}
