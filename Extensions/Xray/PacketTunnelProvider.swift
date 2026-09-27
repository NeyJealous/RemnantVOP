import Darwin
import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var isCoreRunning = false

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            completionHandler(XrayPacketTunnelError.invalidProtocolConfiguration)
            return
        }

        let profile: VPNProfile
        do {
            profile = try TunnelConfigurationStore.profile(from: tunnelProtocol.providerConfiguration)
            guard profile.protocolType == .vless else {
                throw XrayPacketTunnelError.wrongProtocol
            }
        } catch {
            completionHandler(error)
            return
        }

        let settings = makeNetworkSettings()

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else {
                completionHandler(XrayPacketTunnelError.providerUnavailable)
                return
            }
            if let error {
                completionHandler(error)
                return
            }

            do {
                guard let fd = self.findTunnelFileDescriptor() else {
                    throw XrayPacketTunnelError.tunnelDescriptorUnavailable
                }

                let config = try XrayConfigurationBuilder.build(
                    profile: profile,
                    tunnelFileDescriptor: fd
                )

                _ = try XrayBridge.invoke(
                    method: "runXray",
                    payload: ["xrayJson": config]
                )
                self.isCoreRunning = true
                completionHandler(nil)
            } catch {
                XrayBridge.stop()
                self.isCoreRunning = false
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        if isCoreRunning {
            XrayBridge.stop()
        }
        isCoreRunning = false
        completionHandler()
    }

    private func makeNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1400

        let ipv4 = NEIPv4Settings(
            addresses: ["172.20.0.1"],
            subnetMasks: ["255.255.255.252"]
        )
        ipv4.includedRoutes = [.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(
            addresses: ["fdfe:dcba:9876::1"],
            networkPrefixLengths: [126]
        )
        ipv6.includedRoutes = [.default()]
        settings.ipv6Settings = ipv6

        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        return settings
    }

    private func findTunnelFileDescriptor() -> Int32? {
        let utunPrefix = "utun"

        for fd in Int32(0)...Int32(1024) {
            var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
            let result: Int32 = buffer.withUnsafeMutableBytes { rawBuffer in
                var length = socklen_t(rawBuffer.count)
                return getsockopt(fd, 2, 2, rawBuffer.baseAddress, &length)
            }

            guard result == 0 else { continue }

            let name = buffer.withUnsafeBufferPointer { pointer -> String in
                guard let base = pointer.baseAddress else { return "" }
                return String(cString: base)
            }

            if name.hasPrefix(utunPrefix) {
                return fd
            }
        }

        return nil
    }
}

enum XrayPacketTunnelError: LocalizedError {
    case invalidProtocolConfiguration
    case wrongProtocol
    case providerUnavailable
    case tunnelDescriptorUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidProtocolConfiguration:
            return "Некорректная конфигурация Xray Packet Tunnel."
        case .wrongProtocol:
            return "Xray Packet Tunnel получил профиль другого протокола."
        case .providerUnavailable:
            return "Xray Packet Tunnel уже недоступен."
        case .tunnelDescriptorUnavailable:
            return "Не удалось получить файловый дескриптор iOS utun."
        }
    }
}
