import Foundation

/// Append-only newline-delimited JSON log in the shared App Group container.
/// The extension appends; the app reads incrementally from a byte offset.
final class EventLog {
    let url: URL
    private let queue = DispatchQueue(label: "netlens.eventlog")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL = AppConfig.eventLogURL) {
        self.url = url
    }

    func append(_ event: DNSEvent) {
        queue.async { [url, encoder] in
            guard var line = try? encoder.encode(event) else { return }
            line.append(0x0A)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
            } else {
                try? line.write(to: url, options: .atomic)
            }
        }
    }

    struct ReadResult {
        var events: [DNSEvent]
        var nextOffset: UInt64
        /// True when the file shrank (was cleared) and reading restarted at 0.
        var didReset: Bool
    }

    /// Reads complete lines starting at `offset`. A trailing partial line is left for next time.
    func read(from offset: UInt64) -> ReadResult {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ReadResult(events: [], nextOffset: 0, didReset: offset > 0)
        }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        var start = offset
        var didReset = false
        if size < offset {
            start = 0
            didReset = true
        }
        guard size > start else {
            return ReadResult(events: [], nextOffset: start, didReset: didReset)
        }

        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(),
              let lastNewline = data.lastIndex(of: 0x0A) else {
            return ReadResult(events: [], nextOffset: start, didReset: didReset)
        }

        let complete = data[data.startIndex...lastNewline]
        var events: [DNSEvent] = []
        for line in complete.split(separator: 0x0A) where !line.isEmpty {
            if let event = try? decoder.decode(DNSEvent.self, from: Data(line)) {
                events.append(event)
            }
        }
        let consumed = UInt64(complete.count)
        return ReadResult(events: events, nextOffset: start + consumed, didReset: didReset)
    }

    func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
