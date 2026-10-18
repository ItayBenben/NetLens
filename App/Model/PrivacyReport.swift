import Foundation

/// Parsed iOS App Privacy Report (Settings → Privacy & Security → App Privacy Report → Save App Activity).
/// This is the only iOS-sanctioned source that attributes network destinations to specific apps.
struct PrivacyReport {
    struct DomainStat: Identifiable, Hashable {
        let domain: String
        var hits: Int
        var lastSeen: Date?
        var owner: String?
        var initiatedByApp: Bool
        var id: String { domain }
    }

    struct AppActivity: Identifiable, Hashable {
        let bundleID: String
        var domains: [String: DomainStat] = [:]
        var id: String { bundleID }
        var totalHits: Int { domains.values.reduce(0) { $0 + $1.hits } }
        var name: String { AppNames.displayName(for: bundleID) }
        var sortedDomains: [DomainStat] { domains.values.sorted { $0.hits > $1.hits } }
        var trackerDomainCount: Int { domains.keys.filter { TrackerList.category(for: $0) != nil }.count }
    }

    var apps: [String: AppActivity]
    var earliest: Date?
    var latest: Date?

    var sortedApps: [AppActivity] { apps.values.sorted { $0.totalHits > $1.totalHits } }

    struct AppHits: Identifiable {
        let app: AppActivity
        let hits: Int
        var id: String { app.bundleID }
    }

    func apps(contacting domain: String) -> [AppHits] {
        apps.values
            .compactMap { app in app.domains[domain].map { AppHits(app: app, hits: $0.hits) } }
            .sorted { $0.hits > $1.hits }
    }

    // MARK: Parsing

    static func parse(_ data: Data) -> PrivacyReport {
        var report = PrivacyReport(apps: [:])
        for object in jsonObjects(in: data) {
            guard object["type"] as? String == "networkActivity",
                  let domain = (object["domain"] as? String)?.lowercased(), !domain.isEmpty
            else { continue }

            let bundleID = object["bundleID"] as? String ?? "unknown"
            let hits = (object["hits"] as? Int) ?? 1
            let timestamp = (object["timeStamp"] as? String).flatMap(parseDate)
            let firstTimestamp = (object["firstTimeStamp"] as? String).flatMap(parseDate)
            let owner = (object["domainOwner"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let initiatedByApp = (object["initiatedType"] as? String) != "NonAppInitiated"

            var app = report.apps[bundleID] ?? AppActivity(bundleID: bundleID)
            var stat = app.domains[domain] ?? DomainStat(domain: domain, hits: 0, lastSeen: nil, owner: owner, initiatedByApp: initiatedByApp)
            stat.hits += hits
            if let timestamp { stat.lastSeen = max(stat.lastSeen ?? timestamp, timestamp) }
            app.domains[domain] = stat
            report.apps[bundleID] = app

            for date in [firstTimestamp, timestamp].compactMap({ $0 }) {
                report.earliest = min(report.earliest ?? date, date)
                report.latest = max(report.latest ?? date, date)
            }
        }
        return report
    }

    /// Accepts newline-delimited JSON (current format) or a single JSON array.
    private static func jsonObjects(in data: Data) -> [[String: Any]] {
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array
        }
        return data.split(separator: 0x0A).compactMap {
            try? JSONSerialization.jsonObject(with: Data($0)) as? [String: Any]
        }
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plainFormatter = ISO8601DateFormatter()

    private static func parseDate(_ string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? plainFormatter.date(from: string)
    }

    // MARK: Persistence

    static var savedURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app-privacy-report.ndjson")
    }

    static func loadSaved() -> PrivacyReport? {
        guard let data = try? Data(contentsOf: savedURL) else { return nil }
        let report = parse(data)
        return report.apps.isEmpty ? nil : report
    }

    static func importFile(at url: URL) throws -> PrivacyReport {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let report = parse(data)
        guard !report.apps.isEmpty else { throw ImportError.noNetworkActivity }
        try data.write(to: savedURL, options: .atomic)
        return report
    }

    static func deleteSaved() {
        try? FileManager.default.removeItem(at: savedURL)
    }

    enum ImportError: LocalizedError {
        case noNetworkActivity
        var errorDescription: String? {
            "No network activity found. Make sure you picked the file exported from App Privacy Report."
        }
    }
}

enum AppNames {
    private static let known: [String: String] = [
        "com.apple.mobilesafari": "Safari", "com.apple.mobilemail": "Mail",
        "com.apple.MobileSMS": "Messages", "com.apple.Maps": "Maps",
        "com.apple.news": "News", "com.apple.weather": "Weather",
        "com.apple.AppStore": "App Store", "com.apple.Music": "Music",
        "com.apple.podcasts": "Podcasts", "com.apple.stocks": "Stocks",
        "com.google.chrome.ios": "Chrome", "com.google.Gmail": "Gmail",
        "com.google.GoogleMobile": "Google", "com.google.ios.youtube": "YouTube",
        "com.burbn.instagram": "Instagram", "com.facebook.Facebook": "Facebook",
        "net.whatsapp.WhatsApp": "WhatsApp", "com.zhiliaoapp.musically": "TikTok",
        "com.atebits.Tweetie2": "X", "com.spotify.client": "Spotify",
        "ph.telegra.Telegraph": "Telegram", "com.toyopagroup.picaboo": "Snapchat",
        "com.netflix.Netflix": "Netflix", "com.amazon.Amazon": "Amazon",
        "com.microsoft.Office.Outlook": "Outlook", "com.linkedin.LinkedIn": "LinkedIn",
    ]

    static func displayName(for bundleID: String) -> String {
        if let name = known[bundleID] { return name }
        guard let last = bundleID.split(separator: ".").last else { return bundleID }
        return last.prefix(1).uppercased() + last.dropFirst()
    }
}
