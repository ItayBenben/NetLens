import NetworkExtension
import Network

/// A local-only "VPN" that captures DNS lookups.
///
/// Only the fake resolver address is routed into the tunnel, so regular app traffic
/// never passes through this extension. Each DNS query is logged, forwarded to a real
/// resolver, and the answer is written back to the system. Nothing leaves the device
/// except the DNS query itself, which would have been sent anyway.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let queue = DispatchQueue(label: "netlens.dns.forwarder")
    private let log = EventLog()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: [AppConfig.tunnelAddress], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: AppConfig.interceptDNSAddress, subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: [AppConfig.interceptDNSAddress])
        dns.matchDomains = [""]   // send every domain to our resolver
        settings.dnsSettings = dns
        settings.mtu = 1500

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error {
                completionHandler(error)
                return
            }
            self?.readPackets()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            for (packet, family) in zip(packets, protocols) where family.int32Value == AF_INET {
                self.handle(packet)
            }
            self.readPackets()
        }
    }

    private func handle(_ packet: Data) {
        guard let datagram = UDPPacket(ipv4: packet), datagram.destinationPort == 53 else { return }
        let query = DNSMessage(bytes: datagram.payload)
        let started = Date()

        forward(datagram.payload) { [weak self] response in
            guard let self else { return }

            if let response {
                let reply = UDPPacket.makeIPv4(
                    source: datagram.destinationIP,
                    destination: datagram.sourceIP,
                    sourcePort: 53,
                    destinationPort: datagram.sourcePort,
                    payload: response
                )
                self.packetFlow.writePackets([reply], withProtocols: [NSNumber(value: AF_INET)])
            }

            guard let query, !query.isResponse else { return }
            let answer = response.flatMap { DNSMessage(bytes: $0) }
            let latency = response == nil ? nil : Date().timeIntervalSince(started) * 1000

            for question in query.questions where !question.name.isEmpty {
                self.log.append(DNSEvent(
                    id: UUID(),
                    timestamp: started,
                    domain: question.name.lowercased(),
                    queryType: question.type,
                    responseCode: answer?.responseCode,
                    addresses: answer?.addresses ?? [],
                    aliases: answer?.aliases ?? [],
                    latencyMs: latency,
                    querySize: datagram.payload.count,
                    responseSize: response?.count
                ))
            }
        }
    }

    /// Sends one query to the upstream resolver over UDP. The extension's own sockets
    /// are not routed into its tunnel, so this reaches the real network.
    private func forward(_ payload: [UInt8], completion: @escaping ([UInt8]?) -> Void) {
        let server = AppConfig.upstreamDNS[0]
        let connection = NWConnection(host: NWEndpoint.Host(server), port: 53, using: .udp)
        var finished = false

        let finish: ([UInt8]?) -> Void = { result in
            guard !finished else { return }
            finished = true
            connection.cancel()
            completion(result)
        }

        connection.stateUpdateHandler = { state in
            if case .failed = state { finish(nil) }
        }
        connection.start(queue: queue)
        connection.send(content: Data(payload), completion: .contentProcessed { error in
            if error != nil { finish(nil) }
        })
        connection.receiveMessage { data, _, _, _ in
            finish(data.map { [UInt8]($0) })
        }
        queue.asyncAfter(deadline: .now() + 5) {
            finish(nil)
        }
    }
}
