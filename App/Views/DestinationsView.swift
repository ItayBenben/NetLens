import SwiftUI

enum DestinationSort: String, CaseIterable, Identifiable {
    case mostLookups = "Most lookups"
    case mostRecent = "Most recent"
    case name = "Name"
    var id: Self { self }
}

struct DestinationsView: View {
    @EnvironmentObject private var store: TrafficStore
    @State private var search = ""
    @State private var sort = DestinationSort.mostLookups
    @State private var trackersOnly = false
    @State private var groupBySite = false

    private var filtered: [Destination] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let items = store.destinations.values.filter { destination in
            if trackersOnly && destination.category == nil { return false }
            guard !query.isEmpty else { return true }
            return destination.domain.contains(query) || destination.addresses.contains { $0.contains(query) }
        }
        switch sort {
        case .mostLookups: return items.sorted { $0.activityCount > $1.activityCount }
        case .mostRecent: return items.sorted { $0.lastSeen > $1.lastSeen }
        case .name: return items.sorted { $0.domain < $1.domain }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                let items = filtered
                if items.isEmpty {
                    EmptyStateView(
                        title: store.destinations.isEmpty ? "No destinations yet" : "No matches",
                        systemImage: "globe",
                        message: store.destinations.isEmpty
                            ? Edition.emptyDestinationsHint
                            : "Try a different search or filter."
                    )
                    .listRowBackground(Color.clear)
                } else if groupBySite {
                    let groups = Dictionary(grouping: items, by: \.baseDomain)
                        .sorted { $0.value.reduce(0) { $0 + $1.activityCount } > $1.value.reduce(0) { $0 + $1.activityCount } }
                    ForEach(groups, id: \.key) { group in
                        Section("\(group.key) · \(group.value.count)") {
                            ForEach(group.value) { destination in
                                NavigationLink(value: destination.domain) { DestinationRow(destination: destination) }
                            }
                        }
                    }
                } else {
                    Section("\(items.count) destinations") {
                        ForEach(items) { destination in
                            NavigationLink(value: destination.domain) { DestinationRow(destination: destination) }
                        }
                    }
                }
            }
            .navigationTitle("Destinations")
            .navigationDestination(for: String.self) { DestinationDetailView(domain: $0) }
            .searchable(text: $search, prompt: "Domain or IP address")
            .refreshable { store.refresh() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(DestinationSort.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Toggle("Trackers only", isOn: $trackersOnly)
                        Toggle("Group by site", isOn: $groupBySite)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

struct DestinationRow: View {
    let destination: Destination

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(destination.domain)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let category = destination.category {
                        CategoryBadge(category: category)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.number(destination.activityCount))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !destination.addresses.isEmpty { parts.append("\(destination.addresses.count) IPs") }
        if !destination.reportApps.isEmpty {
            parts.append(destination.reportApps.count == 1 ? "1 app" : "\(destination.reportApps.count) apps")
        }
        if destination.lastSeen > .distantPast { parts.append("last \(Format.relative(destination.lastSeen))") }
        return parts.joined(separator: " · ")
    }
}
