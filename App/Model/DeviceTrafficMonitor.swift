import Foundation
import Network
import Darwin

/// Byte counters for the device's physical interfaces (since last boot).
/// iOS exposes these as 32-bit counters, so they wrap every 4 GB per interface.
struct InterfaceCounters: Equatable {
    var wifiReceived: UInt64 = 0
    var wifiSent: UInt64 = 0
    var cellularReceived: UInt64 = 0
    var cellularSent: UInt64 = 0

    var totalReceived: UInt64 { wifiReceived + cellularReceived }
    var totalSent: UInt64 { wifiSent + cellularSent }

    static func - (lhs: InterfaceCounters, rhs: InterfaceCounters) -> InterfaceCounters {
        func sub(_ a: UInt64, _ b: UInt64) -> UInt64 { a >= b ? a - b : 0 }
        return InterfaceCounters(
            wifiReceived: sub(lhs.wifiReceived, rhs.wifiReceived),
            wifiSent: sub(lhs.wifiSent, rhs.wifiSent),
            cellularReceived: sub(lhs.cellularReceived, rhs.cellularReceived),
            cellularSent: sub(lhs.cellularSent, rhs.cellularSent)
        )
    }
}

struct InterfaceAddress: Identifiable, Hashable {
    let interface: String
    let address: String
    let isIPv6: Bool
    var id: String { interface + address }
}

@MainActor
final class DeviceTrafficMonitor: ObservableObject {
    @Published private(set) var counters = InterfaceCounters()
    @Published private(set) var downloadRate: Double = 0   // bytes per second
    @Published private(set) var uploadRate: Double = 0
    @Published private(set) var rateHistory: [RateSample] = []
    @Published private(set) var path: NWPath?
    @Published private(set) var addresses: [InterfaceAddress] = []

    struct RateSample: Identifiable {
        let time: Date
        let download: Double
        let upload: Double
        var id: Date { time }
    }

    private let baseline: InterfaceCounters
    private let pathMonitor = NWPathMonitor()
    private var timer: Timer?
    private var lastSampleTime = Date()

    var sinceAppLaunch: InterfaceCounters { counters - baseline }

    init() {
        let initial = Self.readCounters()
        baseline = initial
        counters = initial
        addresses = Self.readAddresses()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.path = path
                self?.addresses = Self.readAddresses()
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "netlens.path"))
    }

    func start() {
        timer?.invalidate()
        lastSampleTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func sample() {
        let now = Date()
        let current = Self.readCounters()
        let delta = current - counters
        let elapsed = max(now.timeIntervalSince(lastSampleTime), 0.001)
        downloadRate = Double(delta.totalReceived) / elapsed
        uploadRate = Double(delta.totalSent) / elapsed
        counters = current
        lastSampleTime = now
        rateHistory.append(RateSample(time: now, download: downloadRate, upload: uploadRate))
        if rateHistory.count > 60 { rateHistory.removeFirst(rateHistory.count - 60) }
    }

    // MARK: System reads

    private static func readCounters() -> InterfaceCounters {
        var result = InterfaceCounters()
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return result }
        defer { freeifaddrs(list) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let raw = entry.ifa_data
            else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            let name = String(cString: entry.ifa_name)
            if name.hasPrefix("en") {
                result.wifiReceived += UInt64(data.ifi_ibytes)
                result.wifiSent += UInt64(data.ifi_obytes)
            } else if name.hasPrefix("pdp_ip") {
                result.cellularReceived += UInt64(data.ifi_ibytes)
                result.cellularSent += UInt64(data.ifi_obytes)
            }
        }
        return result
    }

    private static func readAddresses() -> [InterfaceAddress] {
        var result: [InterfaceAddress] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return result }
        defer { freeifaddrs(list) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let address = entry.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            let name = String(cString: entry.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            guard !text.hasPrefix("fe80") else { continue }   // skip link-local
            result.append(InterfaceAddress(interface: name, address: text, isIPv6: family == AF_INET6))
        }
        return result
    }
}
