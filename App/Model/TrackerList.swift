import SwiftUI

enum TrackerCategory: String, CaseIterable {
    case advertising = "Advertising"
    case analytics = "Analytics"
    case diagnostics = "Diagnostics"
    case social = "Social"

    var color: Color {
        switch self {
        case .advertising: return .red
        case .analytics: return .orange
        case .diagnostics: return .purple
        case .social: return .blue
        }
    }
}

/// A small built-in list of well-known tracking domains. Matches the domain and every parent domain.
enum TrackerList {
    static let entries: [String: TrackerCategory] = [
        // Advertising
        "doubleclick.net": .advertising, "googlesyndication.com": .advertising,
        "googleadservices.com": .advertising, "adservice.google.com": .advertising,
        "admob.com": .advertising, "adnxs.com": .advertising, "criteo.com": .advertising,
        "criteo.net": .advertising, "taboola.com": .advertising, "outbrain.com": .advertising,
        "applovin.com": .advertising, "applvn.com": .advertising, "unityads.unity3d.com": .advertising,
        "ironsrc.com": .advertising, "ironsrc.mobi": .advertising, "vungle.com": .advertising,
        "chartboost.com": .advertising, "moatads.com": .advertising, "inmobi.com": .advertising,
        "mopub.com": .advertising, "pubmatic.com": .advertising, "rubiconproject.com": .advertising,
        "smaato.net": .advertising, "ads-twitter.com": .advertising, "ads.linkedin.com": .advertising,
        "amazon-adsystem.com": .advertising, "adcolony.com": .advertising, "liftoff.io": .advertising,
        "mintegral.com": .advertising, "pangle.io": .advertising, "byteoversea.com": .advertising,
        "iadsdk.apple.com": .advertising,
        // Analytics & attribution
        "google-analytics.com": .analytics, "app-measurement.com": .analytics,
        "firebaselogging-pa.googleapis.com": .analytics, "appsflyer.com": .analytics,
        "appsflyersdk.com": .analytics, "adjust.com": .analytics, "adjust.net.in": .analytics,
        "branch.io": .analytics, "app.link": .analytics, "kochava.com": .analytics,
        "singular.net": .analytics, "amplitude.com": .analytics, "mixpanel.com": .analytics,
        "segment.io": .analytics, "segment.com": .analytics, "braze.com": .analytics,
        "appboy.com": .analytics, "flurry.com": .analytics, "scorecardresearch.com": .analytics,
        "hotjar.com": .analytics, "heapanalytics.com": .analytics, "clevertap-prod.com": .analytics,
        "onesignal.com": .analytics, "statsig.com": .analytics, "launchdarkly.com": .analytics,
        "fullstory.com": .analytics, "smartlook.com": .analytics, "uxcam.com": .analytics,
        "quantserve.com": .analytics, "chartbeat.com": .analytics, "newrelic.com": .analytics,
        "nr-data.net": .analytics,
        // Diagnostics
        "crashlytics.com": .diagnostics, "sentry.io": .diagnostics, "bugsnag.com": .diagnostics,
        "instabug.com": .diagnostics, "datadoghq.com": .diagnostics, "browser-intake-datadoghq.com": .diagnostics,
        "embrace.io": .diagnostics, "raygun.io": .diagnostics,
        // Social SDKs
        "graph.facebook.com": .social, "connect.facebook.net": .social, "facebook.net": .social,
        "graph.instagram.com": .social, "analytics.tiktok.com": .social, "tiktokv.com": .social,
        "sc-analytics.appspot.com": .social, "analytics.twitter.com": .social,
    ]

    static func category(for domain: String) -> TrackerCategory? {
        var labels = domain.lowercased().split(separator: ".")
        while labels.count >= 2 {
            if let category = entries[labels.joined(separator: ".")] { return category }
            labels.removeFirst()
        }
        return nil
    }
}

enum DomainName {
    private static let secondLevel: Set<String> = ["co", "com", "net", "org", "gov", "edu", "ac", "ne", "or", "go"]

    /// Approximates the registrable domain ("api.cdn.example.co.uk" → "example.co.uk").
    static func base(of domain: String) -> String {
        let labels = domain.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return domain }
        if domain.hasSuffix(".arpa") { return "reverse lookup" }
        let tld = labels[labels.count - 1]
        let sld = labels[labels.count - 2]
        let take = (tld.count == 2 && secondLevel.contains(sld)) ? 3 : 2
        return labels.suffix(take).joined(separator: ".")
    }
}
