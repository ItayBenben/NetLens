import SwiftUI
import Charts
import UIKit

struct DestinationDetailView: View {
    let domain: String
    @EnvironmentObject private var store: TrafficStore

    var body: some View {
        let destination = store.destinations[domain]
        let reportApps = store.report?.apps(contacting: domain) ?? []
        let category = destination?.category ?? TrackerList.category(for: domain)

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(domain)
                        .font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                    HStack {
                        Text(DomainName.base(of: domain)).foregroundStyle(.secondary)
                        if let category { CategoryBadge(category: category) }
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            if let destination, destination.reportHits > 0 {
                Section("App Privacy Report") {
                    LabeledContent("Hits", value: Format.number(destination.reportHits))
                    LabeledContent("Apps", value: "\(destination.reportApps.count)")
                    if destination.lookupCount == 0, destination.lastSeen > .distantPast {
                        LabeledContent("Last seen", value: destination.lastSeen.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }

            if let destination, destination.lookupCount > 0 {
                Section("DNS overview") {
                    LabeledContent("Lookups", value: Format.number(destination.lookupCount))
                    LabeledContent("Failed", value: Format.number(destination.failureCount))
                    LabeledContent("First seen", value: destination.firstSeen.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Last seen", value: destination.lastSeen.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Avg. DNS latency", value: Format.milliseconds(destination.averageLatencyMs))
                    LabeledContent("DNS bytes", value: Format.bytes(destination.bytesTotal))
                }

                Section("Activity · last 24 hours") {
                    Chart(store.hourlyBuckets(for: domain)) { bucket in
                        BarMark(x: .value("Hour", bucket.start, unit: .hour), y: .value("Lookups", bucket.count))
                            .foregroundStyle((category?.color ?? .accentColor).gradient)
                    }
                    .frame(height: 140)
                    .padding(.vertical, 6)
                }

                Section("Resolved IP addresses (\(destination.addresses.count))") {
                    if destination.addresses.isEmpty {
                        Text("No addresses returned").foregroundStyle(.secondary)
                    }
                    ForEach(destination.addresses.sorted(), id: \.self) { address in
                        HStack {
                            Text(address).font(.callout.monospaced())
                            Spacer()
                            Text(address.contains(":") ? "IPv6" : "IPv4").font(.caption).foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button { UIPasteboard.general.string = address } label: { Label("Copy", systemImage: "doc.on.doc") }
                        }
                    }
                }

                if !destination.aliases.isEmpty {
                    Section("CNAME aliases") {
                        ForEach(destination.aliases.sorted(), id: \.self) { alias in
                            Text(alias).font(.callout.monospaced())
                        }
                    }
                }

                Section("Record types") {
                    ForEach(destination.recordTypes.sorted { $0.value > $1.value }, id: \.key) { entry in
                        LabeledContent(entry.key, value: "\(entry.value)")
                    }
                }
            } else if Edition.hasDNSMonitor {
                Section {
                    Text("The DNS monitor hasn’t seen this domain yet. It appears in your App Privacy Report.")
                        .foregroundStyle(.secondary)
                }
            }

            if !reportApps.isEmpty {
                Section("Apps that contacted it (App Privacy Report)") {
                    ForEach(reportApps) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.app.name)
                                Text(item.app.bundleID).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(item.hits) hits").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if (destination?.lookupCount ?? 0) > 0 {
                Section("Recent lookups") {
                    ForEach(store.recentEvents(for: domain)) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.subheadline.monospacedDigit())
                                Text(event.addresses.first ?? event.aliases.first ?? "—")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(event.queryTypeName).font(.caption.monospaced())
                                Text(event.succeeded ? Format.milliseconds(event.latencyMs) : event.responseCodeName)
                                    .font(.caption)
                                    .foregroundStyle(event.succeeded ? Color.secondary : Color.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(DomainName.base(of: domain))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: summary(destination)) { Image(systemName: "square.and.arrow.up") }
            }
        }
    }

    private func summary(_ destination: Destination?) -> String {
        guard let destination else { return domain }
        return """
        \(domain)
        Lookups: \(destination.lookupCount)
        First seen: \(destination.firstSeen.formatted())
        Last seen: \(destination.lastSeen.formatted())
        IPs: \(destination.addresses.sorted().joined(separator: ", "))
        """
    }
}
