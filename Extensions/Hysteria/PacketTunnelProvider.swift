import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var engine: SingBoxEngine?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            completionHandler(HysteriaPacketTunnelError.invalidProtocolConfiguration)
            return
        }

        let profile: VPNProfile
        do {
            profile = try TunnelConfigurationStore.profile(from: tunnelProtocol.providerConfiguration)
            guard profile.protocolType == .hysteria2 else {
                throw HysteriaPacketTunnelError.wrongProtocol
            }
        } catch {
            completionHandler(error)
            return
        }

        let engine = SingBoxEngine(kind: .hysteria2)
        self.engine = engine

        Task {
            do {
                try await engine.start(profile: profile, provider: self)
                completionHandler(nil)
            } catch {
                self.engine = nil
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        guard let engine else {
            completionHandler()
            return
        }

        Task {
            await engine.stop()
            self.engine = nil
            completionHandler()
        }
    }
}

enum HysteriaPacketTunnelError: LocalizedError {
    case invalidProtocolConfiguration
    case wrongProtocol

    var errorDescription: String? {
        switch self {
        case .invalidProtocolConfiguration:
            return "Некорректная конфигурация Hysteria2 Packet Tunnel."
        case .wrongProtocol:
            return "Hysteria2 Packet Tunnel получил профиль другого протокола."
        }
    }
}
