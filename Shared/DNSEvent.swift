import Foundation

/// One DNS lookup observed by the tunnel extension.
struct DNSEvent: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var domain: String
    var queryType: UInt16
    /// nil when the upstream resolver never answered.
    var responseCode: UInt8?
    var addresses: [String]
    var aliases: [String]
    var latencyMs: Double?
    var querySize: Int
    var responseSize: Int?

    var succeeded: Bool { responseCode == 0 }
    var queryTypeName: String { DNSRecordType.name(for: queryType) }
    var responseCodeName: String {
        guard let responseCode else { return "Timeout" }
        return DNSRecordType.responseCodeName(responseCode)
    }
}

enum DNSRecordType {
    static func name(for type: UInt16) -> String {
        switch type {
        case 1: return "A"
        case 2: return "NS"
        case 5: return "CNAME"
        case 6: return "SOA"
        case 12: return "PTR"
        case 15: return "MX"
        case 16: return "TXT"
        case 28: return "AAAA"
        case 33: return "SRV"
        case 64: return "SVCB"
        case 65: return "HTTPS"
        case 255: return "ANY"
        default: return "TYPE\(type)"
        }
    }

    static func responseCodeName(_ code: UInt8) -> String {
        switch code {
        case 0: return "NOERROR"
        case 1: return "FORMERR"
        case 2: return "SERVFAIL"
        case 3: return "NXDOMAIN"
        case 4: return "NOTIMP"
        case 5: return "REFUSED"
        default: return "RCODE\(code)"
        }
    }
}
