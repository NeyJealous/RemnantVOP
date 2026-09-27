import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            completionHandler(XrayPacketTunnelError.invalidProtocolConfiguration)
            return
        }

        do {
            let profile = try TunnelConfigurationStore.profile(from: tunnelProtocol.providerConfiguration)
            guard profile.protocolType == .vless else {
                throw XrayPacketTunnelError.wrongProtocol
            }

            // The Xray extension is deliberately isolated from AWG and Libbox.
            // Runtime wiring is implemented next; this target already reserves
            // the separate process required by libXray's one-Go-runtime rule.
            throw XrayPacketTunnelError.runtimeNotStarted
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

enum XrayPacketTunnelError: LocalizedError {
    case invalidProtocolConfiguration
    case wrongProtocol
    case runtimeNotStarted

    var errorDescription: String? {
        switch self {
        case .invalidProtocolConfiguration:
            return "Некорректная конфигурация Xray Packet Tunnel."
        case .wrongProtocol:
            return "Xray Packet Tunnel получил профиль другого протокола."
        case .runtimeNotStarted:
            return "Xray runtime ещё не подключён к Packet Tunnel."
        }
    }
}
