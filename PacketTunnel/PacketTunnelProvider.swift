import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var engine: VPNEngine?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            completionHandler(PacketTunnelProviderError.invalidProtocolConfiguration)
            return
        }

        let profile: VPNProfile
        do {
            profile = try TunnelConfigurationStore.profile(from: tunnelProtocol.providerConfiguration)
        } catch {
            completionHandler(error)
            return
        }

        let selectedEngine = EngineFactory.make(for: profile.protocolType)
        engine = selectedEngine

        Task {
            do {
                try await selectedEngine.start(profile: profile, provider: self)
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

enum PacketTunnelProviderError: LocalizedError {
    case invalidProtocolConfiguration

    var errorDescription: String? {
        "Некорректная конфигурация NETunnelProviderProtocol."
    }
}
