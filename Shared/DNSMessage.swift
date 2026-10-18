import Foundation
import Darwin

/// Minimal DNS wire-format parser (RFC 1035): header, questions and answer records.
struct DNSMessage {
    struct Question {
        let name: String
        let type: UInt16
    }

    struct Record {
        let name: String
        let type: UInt16
        let ttl: UInt32
        /// IP address for A/AAAA, target name for CNAME, nil otherwise.
        let value: String?
    }

    let id: UInt16
    let flags: UInt16
    let questions: [Question]
    let answers: [Record]

    var isResponse: Bool { flags & 0x8000 != 0 }
    var isTruncated: Bool { flags & 0x0200 != 0 }
    var responseCode: UInt8 { UInt8(flags & 0x000F) }

    var addresses: [String] {
        answers.filter { $0.type == 1 || $0.type == 28 }.compactMap(\.value)
    }

    var aliases: [String] {
        answers.filter { $0.type == 5 }.compactMap(\.value)
    }

    init?(bytes: [UInt8]) {
        var reader = ByteReader(bytes: bytes)
        guard let id = reader.u16(),
              let flags = reader.u16(),
              let questionCount = reader.u16(),
              let answerCount = reader.u16(),
              reader.u16() != nil,   // authority count
              reader.u16() != nil    // additional count
        else { return nil }

        var questions: [Question] = []
        for _ in 0..<Int(questionCount) {
            guard let name = reader.name(), let type = reader.u16(), reader.u16() != nil else { return nil }
            questions.append(Question(name: name, type: type))
        }

        var answers: [Record] = []
        for _ in 0..<Int(answerCount) {
            guard let name = reader.name(),
                  let type = reader.u16(),
                  reader.u16() != nil,
                  let ttl = reader.u32(),
                  let length = reader.u16()
            else { break }
            let start = reader.offset
            let end = start + Int(length)
            guard end <= bytes.count else { break }

            var value: String?
            switch type {
            case 1 where length == 4, 28 where length == 16:
                value = IPFormat.string(Array(bytes[start..<end]))
            case 5:
                var sub = ByteReader(bytes: bytes, offset: start)
                value = sub.name()
            default:
                value = nil
            }
            answers.append(Record(name: name, type: type, ttl: ttl, value: value))
            reader.offset = end
        }

        self.id = id
        self.flags = flags
        self.questions = questions
        self.answers = answers
    }
}

struct ByteReader {
    let bytes: [UInt8]
    var offset = 0

    mutating func u16() -> UInt16? {
        guard offset + 2 <= bytes.count else { return nil }
        defer { offset += 2 }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    mutating func u32() -> UInt32? {
        guard let high = u16(), let low = u16() else { return nil }
        return UInt32(high) << 16 | UInt32(low)
    }

    /// Reads a domain name, following compression pointers.
    mutating func name() -> String? {
        var labels: [String] = []
        var position = offset
        var jumped = false
        var jumps = 0

        while true {
            guard position < bytes.count else { return nil }
            let length = Int(bytes[position])

            if length == 0 {
                position += 1
                break
            }

            if length & 0xC0 == 0xC0 {
                guard position + 1 < bytes.count else { return nil }
                let pointer = ((length & 0x3F) << 8) | Int(bytes[position + 1])
                if !jumped { offset = position + 2 }
                jumped = true
                jumps += 1
                guard jumps < 32 else { return nil }
                position = pointer
                continue
            }

            let labelStart = position + 1
            let labelEnd = labelStart + length
            guard labelEnd <= bytes.count else { return nil }
            labels.append(String(decoding: bytes[labelStart..<labelEnd], as: UTF8.self))
            position = labelEnd
        }

        if !jumped { offset = position }
        return labels.joined(separator: ".")
    }
}

enum IPFormat {
    static func string(_ bytes: [UInt8]) -> String? {
        let family: Int32
        switch bytes.count {
        case 4: family = AF_INET
        case 16: family = AF_INET6
        default: return nil
        }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let ok = bytes.withUnsafeBytes { raw in
            inet_ntop(family, raw.baseAddress, &buffer, socklen_t(buffer.count)) != nil
        }
        return ok ? String(cString: buffer) : nil
    }
}
