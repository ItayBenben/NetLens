# NetLens — iPhone network destinations monitor

NetLens shows every server your iPhone talks to, with per-destination details and device-wide traffic statistics.

## What it shows

| Tab | Contents |
|---|---|
| **Overview** | Monitor on/off · destinations, sites, lookups, trackers, unique IPs, DNS latency, failures · 24-hour activity chart · top 10 destinations · tracker breakdown by category · live download/upload rate · Wi-Fi/cellular byte totals · current network (interface, Low Data Mode, IPv4/IPv6, local IPs) · lookup record types |
| **Destinations** | Searchable list of every hostname (search by domain or IP), sortable, tracker filter, group by site. Detail screen: lookups, first/last seen, latency, resolved IPv4/IPv6 addresses, CNAME chain, 24 h chart, recent lookups, and which **apps** contacted it |
| **Apps** | Imported App Privacy Report: each app's contacted domains, hit counts, tracker count, domain owner |
| **Settings** | Start/stop, always-on (Connect On Demand), import report, export the lookup log as NDJSON, clear data |

## How it works (and why)

iOS doesn't let an app read other apps' traffic. NetLens uses the two mechanisms Apple allows:

1. **On-device DNS monitor**: a `NEPacketTunnelProvider` extension (`PacketTunnel/`). The tunnel routes **only** a fake resolver address (`10.111.222.53/32`) and sets it as the system DNS server. Each lookup is parsed, forwarded to `1.1.1.1`, answered, and logged to a shared App Group file. All other traffic bypasses the extension, so speed and battery are unaffected.
2. **App Privacy Report import**: iOS's own per-app log of contacted domains (Settings → Privacy & Security → App Privacy Report → *Save App Activity*). This is the only supported way to attribute destinations to specific apps.

Device byte counters come from `getifaddrs` (`en*` = Wi-Fi, `pdp_ip*` = cellular), and network state comes from `NWPathMonitor`.

**Limitations:** apps that use their own encrypted DNS, iCloud Private Relay, or another active VPN can bypass the DNS monitor. Only one VPN can be active at a time. Truncated DNS-over-TCP answers aren't handled.

## Building (requires a Mac)

1. Install Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Pick unique identifiers. Replace `com.example.netlens` and `group.com.example.netlens` in **`project.yml`** and **`Shared/AppConfig.swift`**.
3. Set `DEVELOPMENT_TEAM` in `project.yml` to your Team ID.
4. Generate the project and open it:
   ```bash
   cd NetLens
   xcodegen generate
   open NetLens.xcodeproj
   ```
5. Run on a **real iPhone**. Network Extensions don't run in the Simulator. On first start, iOS asks you to allow the VPN configuration.

Network Extension entitlements require a **paid Apple Developer Program** membership. Xcode's automatic signing adds the App Group and Network Extension capabilities to your App IDs.

## Project layout

```
project.yml                 XcodeGen spec (app + extension targets, entitlements, Info.plists)
Shared/                     Compiled into both targets
  AppConfig.swift           App Group, bundle IDs, tunnel addresses
  DNSMessage.swift          DNS wire-format parser
  UDPPacket.swift           IPv4/UDP parse & build
  DNSEvent.swift            Logged lookup model
  EventLog.swift            Shared NDJSON log (append / incremental read)
PacketTunnel/
  PacketTunnelProvider.swift  DNS-only local tunnel
App/
  NetLensApp.swift          Entry point, tabs
  Model/                    TrafficStore, TunnelController, DeviceTrafficMonitor, PrivacyReport, TrackerList
  Views/                    Dashboard, Destinations, Destination detail, Apps, Settings
```
