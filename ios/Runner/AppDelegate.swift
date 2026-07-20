import Flutter
import UIKit
import NetworkExtension
import SystemConfiguration

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let vpnMethodChannel = "com.vpnclient/vpn"
    private let vpnEventChannel = "com.vpnclient/vpn_status"
    fileprivate var statusSink: FlutterEventSink?
    private var vpnManager: NETunnelProviderManager?
    private var connectedSince: Date?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 浼犵粺 Flutter 鎻掍欢娉ㄥ唽锛圴PN 搴旂敤涓嶄娇鐢?ImplicitEngine锛?
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let messenger = controller.binaryMessenger

        // MethodChannel 鈥?鎺ユ敹 Flutter 鐨?VPN 鎸囦护
        let method = FlutterMethodChannel(name: vpnMethodChannel, binaryMessenger: messenger)
        method.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }

        // EventChannel 鈥?鍚?Flutter 鎺ㄩ€?VPN 鐘舵€佸彉鍖?
        let event = FlutterEventChannel(name: vpnEventChannel, binaryMessenger: messenger)
        event.setStreamHandler(VpnStatusStreamHandler(appDelegate: self))

        // 鐩戝惉绯荤粺 VPN 鐘舵€佸彉鍖?
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )

        loadVpnManager()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - VPN Manager 绠＄悊

    private func loadVpnManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let manager = managers?.first {
                self?.vpnManager = manager
            }
        }
    }

    private func ensureVpnManager(completion: @escaping (NETunnelProviderManager) -> Void) {
        if let existing = vpnManager {
            completion(existing)
            return
        }
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "Netsignory VPN"
        let proto = NETunnelProviderProtocol()
        // 鎵╁睍 Bundle ID = 涓诲簲鐢?Bundle ID + ".VPNTunnel"
        proto.providerBundleIdentifier = (Bundle.main.bundleIdentifier ?? "com.netsignory.app") + ".VPNTunnel"
        proto.serverAddress = "vpn.server"
        manager.protocolConfiguration = proto
        manager.isEnabled = true
        manager.saveToPreferences { [weak self] error in
            if error == nil {
                self?.vpnManager = manager
                manager.loadFromPreferences { _ in
                    completion(manager)
                }
            }
        }
    }

    // MARK: - MethodChannel 鎸囦护鍒嗗彂

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Args required", details: nil))
                return
            }
            handleConnect(args: args, result: result)
        case "disconnect":
            handleDisconnect(result: result)
        case "getStatus":
            result(connectionStatusString())
        case "applyNetworkConfig":
            result(nil)
        case "applyDefaultRoute":
            result(nil)
        case "getTunnelStats":
            handleGetTunnelStats(result: result)
        case "pingGateway":
            guard let args = call.arguments as? [String: Any],
                  let ip = args["gatewayIp"] as? String else {
                result(false)
                return
            }
            pingGateway(ip: ip, result: result)
        case "generateKeyPair":
            handleGenerateKeyPair(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 杩炴帴

    private func handleConnect(args: [String: Any], result: @escaping FlutterResult) {
        ensureVpnManager { manager in
            let proto = manager.protocolConfiguration as? NETunnelProviderProtocol
            proto?.providerConfiguration = args
            proto?.serverAddress = (args["server"] as? String) ?? "vpn.server"
            manager.protocolConfiguration = proto
            manager.isEnabled = true
            manager.saveToPreferences { error in
                if let error = error {
                    result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
                    return
                }
                do {
                    try manager.connection.startVPNTunnel()
                    self.connectedSince = Date()
                    result("connected")
                } catch {
                    result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - 鏂紑

    private func handleDisconnect(result: @escaping FlutterResult) {
        vpnManager?.connection.stopVPNTunnel()
        self.connectedSince = nil
        result("disconnected")
    }

    // MARK: - 闅ч亾缁熻锛圛PC 閫氫俊锛?

    private func handleGetTunnelStats(result: @escaping FlutterResult) {
        guard let manager = vpnManager,
              let session = manager.connection as? NETunnelProviderSession else {
            result(nil)
            return
        }
        do {
            try session.sendProviderMessage("stats".data(using: .utf8)!) { data in
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) {
                    result(json)
                } else {
                    result(nil)
                }
            }
        } catch {
            result(nil)
        }
    }

    // MARK: - Ping 缃戝叧

    private func pingGateway(ip: String, result: @escaping FlutterResult) {
        result(isHostReachable(ip))
    }

    // MARK: - 鐢熸垚 WireGuard 瀵嗛挜瀵?

    private func handleGenerateKeyPair(result: @escaping FlutterResult) {
        let privateKey = SecKeyCreateRandomKey([
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrLabel: "com.netsignory.wireguard"
        ] as CFDictionary, nil)
        guard let privateKey = privateKey,
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let pubData = SecKeyCopyExternalRepresentation(publicKey, nil) as? Data else {
            result(FlutterError(code: "KEY_FAILED", message: "Key generation failed", details: nil))
            return
        }
        result(["publicKey": pubData.base64EncodedString()])
    }

    // MARK: - VPN 鐘舵€佺洃鍚?

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        let status = connectionStatusString(from: connection.status)
        statusSink?(status)
    }

    // MARK: - 缃戠粶鍙揪鎬ф娴?

    private func isHostReachable(_ host: String) -> Bool {
        guard let ref = SCNetworkReachabilityCreateWithName(nil, host) else { return false }
        var flags: SCNetworkReachabilityFlags = []
        guard SCNetworkReachabilityGetFlags(ref, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    func connectionStatusString() -> String {
        guard let status = vpnManager?.connection.status else { return "disconnected" }
        return connectionStatusString(from: status)
    }

    private func connectionStatusString(from status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reconnecting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - EventChannel Stream Handler

class VpnStatusStreamHandler: NSObject, FlutterStreamHandler {
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.statusSink = events
        events(appDelegate?.connectionStatusString() ?? "disconnected")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.statusSink = nil
        return nil
    }
}
