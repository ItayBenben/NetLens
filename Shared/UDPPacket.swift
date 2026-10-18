import Foundation

/// Parses and builds IPv4/UDP packets read from / written to the tunnel interface.
struct UDPPacket {
    let sourceIP: [UInt8]
    let destinationIP: [UInt8]
    let sourcePort: UInt16
    let destinationPort: UInt16
    let payload: [UInt8]

    init?(ipv4 data: Data) {
        let b = [UInt8](data)
        guard b.count >= 28, b[0] >> 4 == 4 else { return nil }
        let headerLength = Int(b[0] & 0x0F) * 4
        guard headerLength >= 20, b[9] == 17, b.count >= headerLength + 8 else { return nil }

        let totalLength = min(Int(Self.be16(b, 2)), b.count)
        let udpLength = Int(Self.be16(b, headerLength + 4))
        let end = min(headerLength + udpLength, totalLength)
        guard end >= headerLength + 8 else { return nil }

        sourceIP = Array(b[12..<16])
        destinationIP = Array(b[16..<20])
        sourcePort = Self.be16(b, headerLength)
        destinationPort = Self.be16(b, headerLength + 2)
        payload = Array(b[(headerLength + 8)..<end])
    }

    static func makeIPv4(source: [UInt8], destination: [UInt8],
                         sourcePort: UInt16, destinationPort: UInt16,
                         payload: [UInt8]) -> Data {
        let udpLength = 8 + payload.count
        let totalLength = 20 + udpLength
        var p = [UInt8](repeating: 0, count: 20)

        p[0] = 0x45                              // IPv4, 20-byte header
        p[2] = UInt8(totalLength >> 8)
        p[3] = UInt8(totalLength & 0xFF)
        p[4] = UInt8.random(in: 0...255)         // identification
        p[5] = UInt8.random(in: 0...255)
        p[6] = 0x40                              // don't fragment
        p[8] = 64                                // TTL
        p[9] = 17                                // UDP
        p.replaceSubrange(12..<16, with: source)
        p.replaceSubrange(16..<20, with: destination)
        let checksum = headerChecksum(p)
        p[10] = UInt8(checksum >> 8)
        p[11] = UInt8(checksum & 0xFF)

        p += [
            UInt8(sourcePort >> 8), UInt8(sourcePort & 0xFF),
            UInt8(destinationPort >> 8), UInt8(destinationPort & 0xFF),
            UInt8(udpLength >> 8), UInt8(udpLength & 0xFF),
            0, 0                                 // UDP checksum is optional over IPv4
        ]
        p += payload
        return Data(p)
    }

    private static func be16(_ b: [UInt8], _ i: Int) -> UInt16 {
        UInt16(b[i]) << 8 | UInt16(b[i + 1])
    }

    private static func headerChecksum(_ header: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        for i in stride(from: 0, to: header.count, by: 2) {
            sum += UInt32(header[i]) << 8 | UInt32(header[i + 1])
        }
        while sum > 0xFFFF {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum)
    }
}
