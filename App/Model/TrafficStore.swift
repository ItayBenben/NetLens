import Foundation

/// Aggregated view of one destination hostname.
struct Destination: Identifiable, Hashable {
    let domain: String
    let baseDomain: String
    let category: TrackerCategory?
    var lookupCount = 0
    var failureCount = 0
    var firstSeen: Date
    var lastSeen: Date
    var addresses: Set<String> = []
    var aliases: Set<String> = []
    var recordTypes: [String: Int] = [:]
    var latencyTotal: Double = 0
    var latencySamples = 0
    var bytesTotal = 0
    /// Hits and app bundle IDs from the imported App Privacy Report.
    var reportHits = 0
    var reportApps: Set<String> = []

    var id: String { domain }
    var averageLatencyMs: Double? { latencySamples > 0 ? latencyTotal / Double(latencySamples) : nil }
    /// DNS lookups plus App Privacy Report hits, used for ranking.
    var activityCount: Int { lookupCount + reportHits }

    init(domain: String, firstSeen: Date) {
        self.domain = domain
        self.baseDomain = DomainName.base(of: domain)
        self.category = TrackerList.category(for: domain)
        self.firstSeen = firstSeen
        self.lastSeen = firstSeen
    }
}

struct HourBucket: Identifiable {
    let start: Date
    let count: Int
    var id: Date { start }
}

/// Reads lookups written by the tunnel extension and computes statistics.
@MainActor
final class TrafficStore: ObservableObject {
    @Published private(set) var events: [DNSEvent] = []
    /// DNS-monitor destinations merged with App Privacy Report domains.
    @Published private(set) var destinations: [String: Destination] = [:]
    @Published private(set) var report: PrivacyReport? {
        didSet { mergeDestinations() }
    }
    @Published var importError: String?

    static let maxEventsInMemory = 100_000

    private let log = EventLog()
    private var readOffset: UInt64 = 0
    private var timer: Timer?
    private var dnsDestinations: [String: Destination] = [:] {
        didSet { mergeDestinations() }
    }

    init() {
        report = PrivacyReport.loadSaved()
        mergeDestinations()
        refresh()
    }

    private func mergeDestinations() {
        var merged = dnsDestinations
        let apps = report.map { Array($0.apps.values) } ?? []
        for app in apps {
            for stat in app.domains.values {
                let seen = stat.lastSeen ?? Date.distantPast
                var destination = merged[stat.domain] ?? Destination(domain: stat.domain, firstSeen: seen)
                destination.reportHits += stat.hits
                destination.reportApps.insert(app.bundleID)
                if destination.lookupCount == 0 {
                    destination.firstSeen = min(destination.firstSeen, seen)
                    destination.lastSeen = max(destination.lastSeen, seen)
                }
                merged[stat.domain] = destination
            }
        }
        destinations = merged
    }

    // MARK: Loading

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let result = log.read(from: readOffset)
        if result.didReset {
            events = []
            dnsDestinations = [:]
        }
        readOffset = result.nextOffset
        ingest(result.events)
    }

    private func ingest(_ newEvents: [DNSEvent]) {
        guard !newEvents.isEmpty else { return }
        var updated = dnsDestinations
        for event in newEvents {
            var destination = updated[event.domain] ?? Destination(domain: event.domain, firstSeen: event.timestamp)
            destination.lookupCount += 1
            if !event.succeeded { destination.failureCount += 1 }
            destination.firstSeen = min(destination.firstSeen, event.timestamp)
            destination.lastSeen = max(destination.lastSeen, event.timestamp)
            destination.addresses.formUnion(event.addresses)
            destination.aliases.formUnion(event.aliases)
            destination.recordTypes[event.queryTypeName, default: 0] += 1
            destination.bytesTotal += event.querySize + (event.responseSize ?? 0)
            if let latency = event.latencyMs {
                destination.latencyTotal += latency
                destination.latencySamples += 1
            }
            updated[event.domain] = destination
        }
        dnsDestinations = updated
        events.append(contentsOf: newEvents)
        if events.count > Self.maxEventsInMemory {
            events.removeFirst(events.count - Self.maxEventsInMemory)
        }
    }

    func clearLookups() {
        log.clear()
        readOffset = 0
        events = []
        dnsDestinations = [:]
    }

    // MARK: App Privacy Report

    func importReport(from url: URL) {
        do {
            report = try PrivacyReport.importFile(at: url)
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    func removeReport() {
        PrivacyReport.deleteSaved()
        report = nil
    }

    // MARK: Statistics

    var lookupCount: Int { events.count }
    var failedLookupCount: Int { events.reduce(0) { $0 + ($1.succeeded ? 0 : 1) } }
    var trackerDestinationCount: Int { destinations.values.filter { $0.category != nil }.count }
    var baseDomainCount: Int { Set(destinations.values.map(\.baseDomain)).count }
    var uniqueAddressCount: Int { Set(destinations.values.flatMap(\.addresses)).count }

    var averageLatencyMs: Double? {
        let latencies = events.compactMap(\.latencyMs)
        return latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)
    }

    var lookupsLastHour: Int {
        let cutoff = Date().addingTimeInterval(-3600)
        return events.reversed().prefix { $0.timestamp >= cutoff }.count
    }

    func topDestinations(_ limit: Int) -> [Destination] {
        Array(destinations.values.sorted { $0.activityCount > $1.activityCount }.prefix(limit))
    }

    struct TypeCount: Identifiable {
        let type: String
        let count: Int
        var id: String { type }
    }

    struct TrackerSlice: Identifiable {
        let category: TrackerCategory
        let lookups: Int
        var id: String { category.rawValue }
    }

    func recordTypeBreakdown() -> [TypeCount] {
        var counts: [String: Int] = [:]
        for event in events { counts[event.queryTypeName, default: 0] += 1 }
        return counts.map { TypeCount(type: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    func trackerBreakdown() -> [TrackerSlice] {
        var counts: [TrackerCategory: Int] = [:]
        for destination in destinations.values {
            if let category = destination.category { counts[category, default: 0] += destination.activityCount }
        }
        return counts.map { TrackerSlice(category: $0.key, lookups: $0.value) }.sorted { $0.lookups > $1.lookups }
    }

    func hourlyBuckets(for domain: String? = nil, hours: Int = 24) -> [HourBucket] {
        let calendar = Calendar.current
        guard let currentHour = calendar.dateInterval(of: .hour, for: Date())?.start else { return [] }
        let earliest = currentHour.addingTimeInterval(-Double(hours - 1) * 3600)
        var counts = [Int](repeating: 0, count: hours)
        for event in events.reversed() {
            guard event.timestamp >= earliest else { break }
            guard domain == nil || event.domain == domain else { continue }
            let index = Int(event.timestamp.timeIntervalSince(earliest) / 3600)
            if index >= 0 && index < hours { counts[index] += 1 }
        }
        return counts.enumerated().map { HourBucket(start: earliest.addingTimeInterval(Double($0.offset) * 3600), count: $0.element) }
    }

    func recentEvents(for domain: String, limit: Int = 30) -> [DNSEvent] {
        Array(events.reversed().lazy.filter { $0.domain == domain }.prefix(limit))
    }
}
