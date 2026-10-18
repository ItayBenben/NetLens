import SwiftUI
import UniformTypeIdentifiers

struct AppsView: View {
    @EnvironmentObject private var store: TrafficStore
    @State private var importing = false
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                if let report = store.report {
                    appList(report)
                } else {
                    ScrollView { PrivacyReportInstructions(importing: $importing) }
                        .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Apps")
            .navigationDestination(for: String.self) { DestinationDetailView(domain: $0) }
            .navigationDestination(for: PrivacyReport.AppActivity.self) { AppDetailView(app: $0) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result { store.importReport(from: url) }
            }
            .alert("Import failed", isPresented: Binding(
                get: { store.importError != nil },
                set: { if !$0 { store.importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.importError ?? "")
            }
        }
    }

    private func appList(_ report: PrivacyReport) -> some View {
        let apps = report.sortedApps.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.bundleID.localizedCaseInsensitiveContains(search)
        }
        return List {
            if let earliest = report.earliest, let latest = report.latest {
                Section {
                    LabeledContent("Report covers", value: "\(earliest.formatted(date: .abbreviated, time: .omitted)) – \(latest.formatted(date: .abbreviated, time: .omitted))")
                    LabeledContent("Apps", value: "\(report.apps.count)")
                    LabeledContent("Domains", value: "\(Set(report.apps.values.flatMap { $0.domains.keys }).count)")
                }
            }
            Section("By network activity") {
                ForEach(apps) { app in
                    NavigationLink(value: app) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).font(.subheadline.weight(.medium))
                                Text("\(app.domains.count) domains · \(app.trackerDomainCount) trackers")
                                    .font(.caption)
                                    .foregroundStyle(app.trackerDomainCount > 0 ? Color.red : Color.secondary)
                            }
                            Spacer()
                            Text(Format.number(app.totalHits)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "App name or bundle ID")
    }
}

struct AppDetailView: View {
    let app: PrivacyReport.AppActivity

    var body: some View {
        List {
            Section {
                LabeledContent("Bundle ID", value: app.bundleID).textSelection(.enabled)
                LabeledContent("Total hits", value: Format.number(app.totalHits))
                LabeledContent("Domains contacted", value: "\(app.domains.count)")
                LabeledContent("Tracker domains", value: "\(app.trackerDomainCount)")
            }
            Section("Domains") {
                ForEach(app.sortedDomains) { stat in
                    NavigationLink(value: stat.domain) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(stat.domain).font(.subheadline).lineLimit(1).truncationMode(.middle)
                                    if let category = TrackerList.category(for: stat.domain) { CategoryBadge(category: category) }
                                }
                                HStack(spacing: 4) {
                                    if let owner = stat.owner { Text(owner) }
                                    if !stat.initiatedByApp { Text("· via website") }
                                    if let lastSeen = stat.lastSeen { Text("· \(Format.relative(lastSeen))") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(stat.hits)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(app.name)
    }
}

struct PrivacyReportInstructions: View {
    @Binding var importing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EmptyStateView(
                title: "See which app talks to whom",
                systemImage: "square.grid.2x2",
                message: "iOS only shares per-app network activity through the App Privacy Report. Export it and import it here."
            )
            Card("How to export", systemImage: "list.number") {
                step(1, "Open Settings → Privacy & Security → App Privacy Report.")
                step(2, "Turn on App Privacy Report if it’s off, then use your phone for a while.")
                step(3, "Scroll to the bottom and tap “Save App Activity”. Save it to Files.")
                step(4, "Come back here and import the saved .ndjson file.")
            }
            Button {
                importing = true
            } label: {
                Label("Import App Privacy Report", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(text).font(.subheadline)
        }
    }
}
