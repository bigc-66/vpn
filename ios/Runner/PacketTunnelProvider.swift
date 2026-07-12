import NetworkExtension
import Network
import os.log

/// iOS Packet Tunnel Provider — Network Extension 进程中运行。
///
/// WireGuard: 使用 WireGuardKit (WireGuardAdapter) 加密包转发。
/// SSL: 使用 NWConnection TLS 隧道进行加密包转发。
class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.netsignory.app.tunnel", category: "tunnel")

    private var sslConnection: NWConnection?
    private var txBytes: Int64 = 0
    private var rxBytes: Int64 = 0

    override func startTunnel(
        options: [String : NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        os_log("startTunnel called", log: log, type: .info)

        guard let config = protocolConfiguration as? NETunnelProviderProtocol,
              let params = config.providerConfiguration else {
            completionHandler(NSError(domain: "VPN", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "缺少连接参数"]))
            return
        }

        let server = params["server"] as? String ?? ""
        let port = params["port"] as? Int ?? 443
        let proto = params["protocol"] as? String ?? "wireguard"
        let publicKey = params["serverPublicKey"] as? String ?? ""

        os_log("Connecting to %{public}@:%d via %{public}@", log: log, type: .info, server, port, proto)

        // ─── 第一阶段网络配置 ───
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: server)

        // DNS
        if let dnsServers = params["dnsServers"] as? [String], !dnsServers.isEmpty {
            tunnelSettings.dnsSettings = NEDNSSettings(servers: dnsServers)
        }

        // MTU
        tunnelSettings.mtu = NSNumber(value: 1380)

        // IPv4 — 隧道地址
        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.255"])
        // 第一阶段仅添加非默认路由
        ipv4.includedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0")
        ]
        // endpoint 直连路由（不走隧道）
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: server, subnetMask: "255.255.255.255")
        ]
        tunnelSettings.ipv4Settings = ipv4

        // 应用网络配置
        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                os_log("设置网络配置失败: %{public}@", log: self?.log ?? .default, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }

            // ─── 协议握手 ───
            // 这里是与 WireGuard/SSL 协议库的集成点。
            // 任务发布方将提供协议库源码，集成时在此处调用。
            //
            // WireGuard: 使用 wireguard-go 的 Swift 绑定
            // SSL VPN:   使用 OpenSSL/BoringSSL 建立 TLS 隧道
            self?.performHandshake(server: server, port: port, proto: proto, publicKey: publicKey) { success in
                if success {
                    os_log("协议握手成功", log: self?.log ?? .default, type: .info)
                    completionHandler(nil)
                    // 开始包转发
                    self?.startPacketForwarding()
                } else {
                    completionHandler(NSError(domain: "VPN", code: -2,
                                              userInfo: [NSLocalizedDescriptionKey: "协议握手失败"]))
                }
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        os_log("stopTunnel reason=%d", log: log, type: .info, reason.rawValue)
        sslConnection?.cancel()
        sslConnection = nil
        completionHandler()
    }

    // MARK: - SSL TLS 隧道

    private func startSslTunnel(
        server: String,
        port: Int,
        username: String,
        password: String,
        completion: @escaping (Bool) -> Void
    ) {
        let tlsParams = NWProtocolTLS.Options()
        let tcpParams = NWProtocolTCP.Options()
        tcpParams.connectionTimeout = 10

        let params = NWParameters(tls: tlsParams, tcp: tcpParams)
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(server),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        let conn = NWConnection(to: endpoint, using: params)
        self.sslConnection = conn

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // 发送认证帧
                let authMsg = "AUTH \(username) \(password)\n".data(using: .utf8)!
                conn.send(content: authMsg, completion: .contentProcessed { error in
                    if let error = error {
                        os_log("AUTH 发送失败: %{public}@", log: self?.log ?? .default, type: .error, error.localizedDescription)
                        completion(false)
                        return
                    }
                    // 读取响应
                    conn.receive(minimumIncompleteLength: 2, maximumLength: 64) { data, _, _, recvError in
                        guard let data = data,
                              let resp = String(data: data, encoding: .utf8),
                              resp.hasPrefix("OK"),
                              recvError == nil else {
                            os_log("AUTH 失败", log: self?.log ?? .default, type: .error)
                            completion(false)
                            return
                        }
                        os_log("SSL 握手成功", log: self?.log ?? .default, type: .info)
                        completion(true)
                    }
                })
            case .failed(let error):
                os_log("NWConnection 失败: %{public}@", log: self?.log ?? .default, type: .error, error.localizedDescription)
                completion(false)
            default:
                break
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - 双向包转发

    private func startPacketForwarding() {
        readOutboundPackets()
        readInboundData()
    }

    /// 出站: packetFlow → NWConnection (4字节长度前缀 + 数据)
    private func readOutboundPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, let conn = self.sslConnection else { return }
            for packet in packets {
                var len = UInt32(packet.count).bigEndian
                var frame = Data(bytes: &len, count: 4)
                frame.append(packet)
                conn.send(content: frame, completion: .contentProcessed { _ in })
                self.txBytes += Int64(packet.count)
            }
            self.readOutboundPackets()
        }
    }

    /// 入站: NWConnection → packetFlow
    private func readInboundData() {
        guard let conn = sslConnection else { return }
        // 读 4 字节长度头
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, _, error in
            guard let self = self, let header = header, header.count == 4, error == nil else { return }
            let len = Int(header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            guard len > 0, len <= 65535 else {
                self.readInboundData()
                return
            }
            conn.receive(minimumIncompleteLength: len, maximumLength: len) { [weak self] data, _, _, error in
                guard let self = self, let data = data, error == nil else { return }
                self.packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
                self.rxBytes += Int64(data.count)
                self.readInboundData()
            }
        }
    }

    // MARK: - 协议握手分发

    private func performHandshake(
        server: String,
        port: Int,
        proto: String,
        publicKey: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard !server.isEmpty else {
            completion(false)
            return
        }
        if proto == "wireguard" && publicKey.isEmpty {
            completion(false)
            return
        }

        let username = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["username"] as? String ?? ""
        let password = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["password"] as? String ?? ""

        if proto == "wireguard" {
            // WireGuard: 需集成 WireGuardKit SPM
            os_log("WireGuard 需要 WireGuardKit 依赖", log: log, type: .error)
            completion(false)
        } else {
            startSslTunnel(server: server, port: port, username: username, password: password, completion: completion)
        }
    }

    // MARK: - App Message (stats)

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let cmd = String(data: messageData, encoding: .utf8), cmd == "stats" {
            let stats: [String: Any] = [
                "txBytes": txBytes,
                "rxBytes": rxBytes,
                "status": "connected"
            ]
            if let json = try? JSONSerialization.data(withJSONObject: stats) {
                completionHandler?(json)
            } else {
                completionHandler?(nil)
            }
        } else {
            completionHandler?(nil)
        }
    }

    /// 第二阶段：隧道就绪后添加默认路由
    func applyDefaultRoute() {
        guard let config = protocolConfiguration as? NETunnelProviderProtocol,
              let params = config.providerConfiguration,
              let server = params["server"] as? String else { return }

        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: server)
        tunnelSettings.mtu = NSNumber(value: 1380)

        if let dnsServers = params["dnsServers"] as? [String], !dnsServers.isEmpty {
            tunnelSettings.dnsSettings = NEDNSSettings(servers: dnsServers)
        }

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.255"])
        // 默认路由 — 全流量走隧道
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: server, subnetMask: "255.255.255.255")
        ]
        tunnelSettings.ipv4Settings = ipv4

        setTunnelNetworkSettings(tunnelSettings) { error in
            if let error = error {
                os_log("applyDefaultRoute 失败: %{public}@", type: .error, error.localizedDescription)
            }
        }
    }
}
