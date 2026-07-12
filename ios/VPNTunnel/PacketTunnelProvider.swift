import NetworkExtension
import Network
import os.log

/// iOS Packet Tunnel Provider — 在 Network Extension 进程中运行。
///
/// WireGuard 协议：使用 WireGuardKit (WireGuardAdapter) 进行加密包转发。
/// SSL 协议：使用 NWConnection TLS 隧道进行加密包转发。
///
/// 集成 WireGuardKit SPM 后取消对应注释即可启用 WireGuard 内核加密。
class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.netsignory.app.VPNTunnel", category: "tunnel")

    // WireGuard: 取消注释（需添加 WireGuardKit SPM 依赖）
    // import WireGuardKit
    // private lazy var wgAdapter: WireGuardAdapter = {
    //     WireGuardAdapter(with: self) { logLevel, message in
    //         os_log("%{public}@", type: .debug, message)
    //     }
    // }()

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
        let clientPrivateKey = params["clientPrivateKey"] as? String ?? ""

        os_log("Connecting to %{public}@:%d via %{public}@", log: log, type: .info, server, port, proto)

        // ─── 第一阶段网络配置 ───
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: server)

        if let dnsServers = params["dnsServers"] as? [String], !dnsServers.isEmpty {
            tunnelSettings.dnsSettings = NEDNSSettings(servers: dnsServers)
        }

        tunnelSettings.mtu = NSNumber(value: 1380)

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0")
        ]
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: server, subnetMask: "255.255.255.255")
        ]
        tunnelSettings.ipv4Settings = ipv4

        setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
            if let error = error {
                os_log("设置网络配置失败: %{public}@", log: self?.log ?? .default, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }

            self?.performHandshake(
                server: server, port: port, proto: proto,
                publicKey: publicKey, clientPrivateKey: clientPrivateKey
            ) { success in
                if success {
                    os_log("协议握手成功", log: self?.log ?? .default, type: .info)
                    completionHandler(nil)
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
        // WireGuard: wgAdapter.stop { completionHandler() }
        completionHandler()
    }

    // MARK: - 协议握手

    /// WireGuard 握手（需 WireGuardKit SPM）:
    /// ```swift
    /// let wgConfig = """
    /// [Interface]
    /// PrivateKey = \(clientPrivateKey)
    /// Address = 10.0.0.2/32
    /// DNS = 8.8.8.8
    ///
    /// [Peer]
    /// PublicKey = \(publicKey)
    /// Endpoint = \(server):\(port)
    /// AllowedIPs = 0.0.0.0/0
    /// PersistentKeepalive = 25
    /// """
    /// let tunnelConfig = try TunnelConfiguration(fromWgQuickConfig: wgConfig, called: "wg0")
    /// wgAdapter.start(tunnelConfiguration: tunnelConfig) { error in
    ///     completion(error == nil)
    /// }
    /// ```
    private func performHandshake(
        server: String, port: Int, proto: String,
        publicKey: String, clientPrivateKey: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard !server.isEmpty else { completion(false); return }

        if proto == "wireguard" {
            guard !publicKey.isEmpty, !clientPrivateKey.isEmpty else {
                completion(false)
                return
            }
            // --- WireGuard 路径（取消注释以启用）---
            // let wgConfig = """
            // [Interface]
            // PrivateKey = \(clientPrivateKey)
            // Address = 10.0.0.2/32
            // DNS = 8.8.8.8
            //
            // [Peer]
            // PublicKey = \(publicKey)
            // Endpoint = \(server):\(port)
            // AllowedIPs = 0.0.0.0/0
            // PersistentKeepalive = 25
            // """
            // do {
            //     let tunnelConfig = try TunnelConfiguration(fromWgQuickConfig: wgConfig, called: "wg0")
            //     wgAdapter.start(tunnelConfiguration: tunnelConfig) { adapterError in
            //         completion(adapterError == nil)
            //     }
            // } catch {
            //     os_log("WireGuard config parse error: %{public}@", log: self.log, type: .error, error.localizedDescription)
            //     completion(false)
            // }
            // return

            // 临时占位：WireGuardKit 未集成时使用 NWConnection 回落
            startSslTunnel(server: server, port: port, completion: completion)
        } else {
            // SSL 协议路径
            startSslTunnel(server: server, port: port, completion: completion)
        }
    }

    // MARK: - SSL 隧道（NWConnection TLS）

    private func startSslTunnel(server: String, port: Int, completion: @escaping (Bool) -> Void) {
        let host = NWEndpoint.Host(server)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) ?? .https
        let tlsParams = NWProtocolTLS.Options()
        let tcpParams = NWProtocolTCP.Options()
        tcpParams.connectionTimeout = 10
        let params = NWParameters(tls: tlsParams, tcp: tcpParams)

        let connection = NWConnection(host: host, port: nwPort, using: params)
        self.sslConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                os_log("SSL tunnel connected", log: self?.log ?? .default, type: .info)
                completion(true)
            case .failed(let error):
                os_log("SSL tunnel failed: %{public}@", log: self?.log ?? .default, type: .error, error.localizedDescription)
                completion(false)
            case .cancelled:
                os_log("SSL tunnel cancelled", log: self?.log ?? .default, type: .info)
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - 包转发

    private func startPacketForwarding() {
        // WireGuard: WireGuardAdapter 自行管理内核包转发，无需用户态循环
        // SSL: 使用 packetFlow + NWConnection 进行双向转发
        guard sslConnection != nil else { return }
        readOutboundPackets()
        readInboundData()
    }

    /// 出站：TUN → SSL
    private func readOutboundPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, let conn = self.sslConnection else { return }
            for packet in packets {
                self.txBytes += Int64(packet.count)
                // 发送 IP 包到 SSL 隧道（带 4 字节长度前缀）
                var length = UInt32(packet.count).bigEndian
                var frame = Data(bytes: &length, count: 4)
                frame.append(packet)
                conn.send(content: frame, completion: .contentProcessed { error in
                    if let error = error {
                        os_log("SSL send error: %{public}@", type: .error, error.localizedDescription)
                    }
                })
            }
            self.readOutboundPackets() // 继续读取
        }
    }

    /// 入站：SSL → TUN
    private func readInboundData() {
        guard let conn = sslConnection else { return }
        // 先读 4 字节长度头
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, _, error in
            guard let self = self else { return }
            if let error = error {
                os_log("SSL recv header error: %{public}@", log: self.log, type: .error, error.localizedDescription)
                return
            }
            guard let header = header, header.count == 4 else {
                self.readInboundData()
                return
            }
            let length = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0, length <= 65535 else {
                self.readInboundData()
                return
            }
            // 读取 IP 包体
            conn.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] body, _, _, error in
                guard let self = self else { return }
                if let body = body, !body.isEmpty {
                    self.rxBytes += Int64(body.count)
                    self.packetFlow.writePackets([body], withProtocols: [NSNumber(value: AF_INET)])
                }
                self.readInboundData()
            }
        }
    }

    // MARK: - Provider Message Handler

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let str = String(data: messageData, encoding: .utf8), str == "stats" {
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
