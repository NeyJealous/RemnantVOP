import Foundation
import NetworkExtension
import WireGuardKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var adapter: WireGuardAdapter?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            completionHandler(AWGPacketTunnelError.invalidProtocolConfiguration)
            return
        }

        do {
            let profile = try TunnelConfigurationStore.profile(from: tunnelProtocol.providerConfiguration)
            guard profile.protocolType == .amneziaWG else {
                throw AWGPacketTunnelError.wrongProtocol
            }

            let quickConfig = try AmneziaAWGConfigExtractor.configurationText(from: profile)
            let configuration = try AWGQuickConfigParser.parse(quickConfig, name: profile.name)

            let adapter = WireGuardAdapter(with: self) { level, message in
                #if DEBUG
                let prefix = level == .error ? "[AWG:error]" : "[AWG]"
                print("\(prefix) \(message)")
                #endif
            }

            adapter.start(tunnelConfiguration: configuration) { [weak self] error in
                if error == nil {
                    self?.adapter = adapter
                }
                completionHandler(error)
            }
        } catch {
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        guard let adapter else {
            completionHandler()
            return
        }

        adapter.stop { [weak self] _ in
            self?.adapter = nil
            completionHandler()
        }
    }
}

enum AWGPacketTunnelError: LocalizedError {
    case invalidProtocolConfiguration
    case wrongProtocol

    var errorDescription: String? {
        switch self {
        case .invalidProtocolConfiguration:
            return "Некорректная конфигурация AWG Packet Tunnel."
        case .wrongProtocol:
            return "AWG Packet Tunnel получил профиль другого протокола."
        }
    }
}
