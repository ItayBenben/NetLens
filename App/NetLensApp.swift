import SwiftUI

@main
struct NetLensApp: App {
    @StateObject private var store = TrafficStore()
    @StateObject private var tunnel = TunnelController()
    @StateObject private var device = DeviceTrafficMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(tunnel)
                .environmentObject(device)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TrafficStore
    @EnvironmentObject private var device: DeviceTrafficMonitor
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "chart.bar.xaxis") }
            DestinationsView()
                .tabItem { Label("Destinations", systemImage: "globe") }
            AppsView()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear(perform: resume)
        .onChange(of: scenePhase) { phase in
            if phase == .active { resume() } else { pause() }
        }
    }

    private func resume() {
        store.refresh()
        store.startPolling()
        device.start()
    }

    private func pause() {
        store.stopPolling()
        device.stop()
    }
}
