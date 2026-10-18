import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TrafficStore
    @EnvironmentObject private var tunnel: TunnelController
    @State private var importing = false
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Form {
                if Edition.hasDNSMonitor {
                    monitorSections
                } else {
                    Section("How it works") {
                        Text("NetLens Lite reads your App Privacy Report (Settings → Privacy & Security → App Privacy Report → Save App Activity) to list every domain your apps contacted. Everything stays on your phone.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("App Privacy Report") {
                    Button("Import report…") { importing = true }
                    if store.report != nil {
                        Button("Remove imported report", role: .destructive) { store.removeReport() }
                    }
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result { store.importReport(from: url) }
            }
            .confirmationDialog("Delete all recorded lookups?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { store.clearLookups() }
            }
        }
    }

    @ViewBuilder
    private var monitorSections: some View {
        Section {
            LabeledContent("Status", value: tunnel.status.label)
            Toggle("Monitor DNS lookups", isOn: Binding(
                get: { tunnel.isActive },
                set: { on in
                    Task {
                        if on { await tunnel.start() } else { await tunnel.stop() }
                    }
                }
            ))
            Toggle("Keep monitoring on", isOn: Binding(
                get: { tunnel.onDemandEnabled },
                set: { on in Task { await tunnel.setOnDemand(on) } }
            ))
        } header: {
            Text("Monitoring")
        } footer: {
            Text("“Keep monitoring on” restarts the monitor automatically after reboots or network changes.")
        }

        Section("Data") {
            LabeledContent("Lookups stored", value: Format.number(store.lookupCount))
            ShareLink(item: AppConfig.eventLogURL) {
                Label("Export lookup log (NDJSON)", systemImage: "square.and.arrow.up")
            }
            .disabled(store.lookupCount == 0)
            Button("Clear all lookups", role: .destructive) { confirmClear = true }
        }

        Section("How it works") {
            Text("NetLens installs a local VPN profile that only intercepts DNS. Your other traffic doesn’t pass through it, and no data leaves your phone other than the DNS lookups themselves, which are forwarded to \(AppConfig.upstreamDNS[0]).")
            Text("Apps that use their own encrypted DNS (DoH/DoT), iCloud Private Relay, or another VPN may bypass the monitor. For per-app attribution, import the App Privacy Report.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
