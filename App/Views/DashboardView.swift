import SwiftUI
import Charts
import Network

struct DashboardView: View {
    @EnvironmentObject private var store: TrafficStore
    @EnvironmentObject private var device: DeviceTrafficMonitor

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if Edition.hasDNSMonitor {
                        MonitorCard()
                        statsGrid
                        activityCard
                    } else {
                        liteStatsGrid
                    }
                    topDestinationsCard
                    trackersCard
                    deviceTrafficCard
                    networkCard
                    if Edition.hasDNSMonitor {
                        recordTypesCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("NetLens")
            .navigationDestination(for: String.self) { DestinationDetailView(domain: $0) }
            .refreshable {
                store.refresh()
                device.sample()
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(value: Format.number(store.destinations.count), label: "Destinations", systemImage: "globe")
            StatTile(value: Format.number(store.baseDomainCount), label: "Organizations / sites", systemImage: "building.2")
            StatTile(value: Format.number(store.lookupCount), label: "Total lookups", systemImage: "magnifyingglass")
            StatTile(value: Format.number(store.lookupsLastHour), label: "Lookups last hour", systemImage: "clock")
            StatTile(value: Format.number(store.trackerDestinationCount), label: "Tracker domains", systemImage: "eye.trianglebadge.exclamationmark", tint: .red)
            StatTile(value: Format.number(store.uniqueAddressCount), label: "Unique IP addresses", systemImage: "network")
            StatTile(value: Format.milliseconds(store.averageLatencyMs), label: "Avg. DNS latency", systemImage: "timer", tint: .green)
            StatTile(value: Format.number(store.failedLookupCount), label: "Failed lookups", systemImage: "xmark.octagon", tint: .orange)
        }
    }

    private var liteStatsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(value: Format.number(store.destinations.count), label: "Destinations", systemImage: "globe")
            StatTile(value: Format.number(store.baseDomainCount), label: "Organizations / sites", systemImage: "building.2")
            StatTile(value: Format.number(store.report?.apps.count ?? 0), label: "Apps with activity", systemImage: "square.grid.2x2")
            StatTile(value: Format.number(store.trackerDestinationCount), label: "Tracker domains", systemImage: "eye.trianglebadge.exclamationmark", tint: .red)
        }
    }

    private var activityCard: some View {
        Card("Activity · last 24 hours", systemImage: "waveform.path.ecg") {
            Chart(store.hourlyBuckets()) { bucket in
                BarMark(
                    x: .value("Hour", bucket.start, unit: .hour),
                    y: .value("Lookups", bucket.count)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 160)
        }
    }

    @ViewBuilder
    private var topDestinationsCard: some View {
        let top = store.topDestinations(10)
        Card("Top destinations", systemImage: "list.number") {
            if top.isEmpty {
                Text(Edition.emptyDestinationsHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(top) { destination in
                    BarMark(
                        x: .value("Activity", destination.activityCount),
                        y: .value("Domain", destination.domain)
                    )
                    .foregroundStyle(destination.category?.color ?? Color.accentColor)
                    .annotation(position: .trailing) {
                        Text("\(destination.activityCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(top.count) * 30)

                ForEach(top.prefix(3)) { destination in
                    NavigationLink(value: destination.domain) {
                        DestinationRow(destination: destination)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var trackersCard: some View {
        let breakdown = store.trackerBreakdown()
        if !breakdown.isEmpty {
            Card("Trackers contacted", systemImage: "eye.trianglebadge.exclamationmark") {
                if #available(iOS 17.0, *) {
                    Chart(breakdown) { item in
                        SectorMark(angle: .value("Lookups", item.lookups), innerRadius: .ratio(0.6))
                            .foregroundStyle(item.category.color)
                    }
                    .frame(height: 150)
                }
                ForEach(breakdown) { item in
                    HStack {
                        Circle().fill(item.category.color).frame(width: 8, height: 8)
                        Text(item.category.rawValue)
                        Spacer()
                        Text("\(item.lookups) lookups").foregroundStyle(.secondary).monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var deviceTrafficCard: some View {
        Card("Device traffic", systemImage: "arrow.up.arrow.down") {
            HStack {
                rateLabel("Download", device.downloadRate, "arrow.down.circle.fill", .blue)
                Spacer()
                rateLabel("Upload", device.uploadRate, "arrow.up.circle.fill", .green)
            }

            Chart(device.rateHistory) { sample in
                LineMark(x: .value("Time", sample.time), y: .value("Bytes/s", sample.download), series: .value("Dir", "Down"))
                    .foregroundStyle(.blue)
                LineMark(x: .value("Time", sample.time), y: .value("Bytes/s", sample.upload), series: .value("Dir", "Up"))
                    .foregroundStyle(.green)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text(Format.rate(bytes))
                        }
                    }
                }
            }
            .frame(height: 120)

            Divider()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    Text("Received").font(.caption).foregroundStyle(.secondary)
                    Text("Sent").font(.caption).foregroundStyle(.secondary)
                }
                GridRow {
                    Label("Wi-Fi", systemImage: "wifi")
                    Text(Format.bytes(device.counters.wifiReceived))
                    Text(Format.bytes(device.counters.wifiSent))
                }
                GridRow {
                    Label("Cellular", systemImage: "antenna.radiowaves.left.and.right")
                    Text(Format.bytes(device.counters.cellularReceived))
                    Text(Format.bytes(device.counters.cellularSent))
                }
                GridRow {
                    Label("This session", systemImage: "app.badge")
                    Text(Format.bytes(device.sinceAppLaunch.totalReceived))
                    Text(Format.bytes(device.sinceAppLaunch.totalSent))
                }
            }
            .font(.subheadline)
            .monospacedDigit()
            Text("Interface totals since the phone last restarted. iOS counters wrap at 4 GB.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func rateLabel(_ title: String, _ rate: Double, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.title2)
            VStack(alignment: .leading) {
                Text(Format.rate(rate)).font(.headline).monospacedDigit()
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var networkCard: some View {
        Card("Current network", systemImage: "point.3.connected.trianglepath.dotted") {
            if let path = device.path {
                LabeledContent("Status", value: path.status == .satisfied ? "Connected" : "Offline")
                LabeledContent("Interface", value: path.interfaceDescription)
                LabeledContent("Low Data Mode", value: path.isConstrained ? "On" : "Off")
                LabeledContent("Metered (expensive)", value: path.isExpensive ? "Yes" : "No")
                LabeledContent("IPv4 / IPv6", value: "\(path.supportsIPv4 ? "Yes" : "No") / \(path.supportsIPv6 ? "Yes" : "No")")
            }
            ForEach(device.addresses) { address in
                LabeledContent(address.interface, value: address.address)
                    .textSelection(.enabled)
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var recordTypesCard: some View {
        let types = store.recordTypeBreakdown()
        if !types.isEmpty {
            Card("Lookup types", systemImage: "tag") {
                ForEach(types) { item in
                    HStack {
                        Text(item.type).font(.subheadline.monospaced())
                        ProgressView(value: Double(item.count), total: Double(max(store.lookupCount, 1)))
                        Text("\(item.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MonitorCard: View {
    @EnvironmentObject private var tunnel: TunnelController

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tunnel.isActive ? "dot.radiowaves.left.and.right" : "pause.circle")
                .font(.title)
                .foregroundStyle(tunnel.isActive ? .green : .secondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("DNS monitor").font(.headline)
                Text(tunnel.status.label).font(.subheadline).foregroundStyle(.secondary)
                if let error = tunnel.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            Button(tunnel.isActive ? "Stop" : "Start") {
                Task {
                    if tunnel.isActive { await tunnel.stop() } else { await tunnel.start() }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(tunnel.isActive ? .red : .accentColor)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension NWPath {
    var interfaceDescription: String {
        if usesInterfaceType(.wifi) { return "Wi-Fi" }
        if usesInterfaceType(.cellular) { return "Cellular" }
        if usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        if usesInterfaceType(.other) { return "Other" }
        return "None"
    }
}
