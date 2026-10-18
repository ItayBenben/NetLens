import Foundation

/// The Lite edition (target `NetLensLite`, compiled with the `LITE` flag) has no packet
/// tunnel extension, so it can be signed with a free Apple ID. Destinations come from
/// the imported App Privacy Report instead of the live DNS monitor.
enum Edition {
    #if LITE
    static let hasDNSMonitor = false
    #else
    static let hasDNSMonitor = true
    #endif

    static var emptyDestinationsHint: String {
        hasDNSMonitor
            ? "Start the DNS monitor from the Overview tab, or import your App Privacy Report in the Apps tab."
            : "Import your App Privacy Report in the Apps tab to see every domain your apps contacted."
    }
}
