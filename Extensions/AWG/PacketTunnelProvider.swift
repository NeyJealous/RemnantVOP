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

            let runtimeOptions = TunnelConfigurationStore.runtimeOptions(
                from: tunnelProtocol.providerConfiguration
            )
            let quickConfig = try AmneziaAWGConfigExtractor.configurationText(from: profile)
            let effectiveConfig = overridingDNS(
                in: quickConfig,
                servers: runtimeOptions.dnsServers
            )
            let configuration = try AWGQuickConfigParser.parse(
                effectiveConfig,
                name: profile.name
            )

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

    private func overridingDNS(in source: String, servers: [String]) -> String {
        guard !servers.isEmpty else { return source }

        var output: [String] = []
        var inInterface = false
        var inserted = false

        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.lowercased() == "[interface]" {
                inInterface = true
                output.append(line)
                continue
            }

            if trimmed.lowercased() == "[peer]" {
                if inInterface && !inserted {
                    output.append("DNS = \(servers.joined(separator: ", "))")
                    inserted = true
                }
                inInterface = false
                output.append(line)
                continue
            }

            if inInterface,
               trimmed.lowercased().hasPrefix("dns"),
               trimmed.contains("=") {
                continue
            }

            output.append(line)
        }

        if inInterface && !inserted {
            output.append("DNS = \(servers.joined(separator: ", "))")
        }

        return output.joined(separator: "\n")
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
