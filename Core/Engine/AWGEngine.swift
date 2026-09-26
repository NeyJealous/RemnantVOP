import Foundation
import NetworkExtension
import WireGuardKit

final class AWGEngine: VPNEngine {
    let kind: TunnelProtocol = .amneziaWG

    private var adapter: WireGuardAdapter?

    func start(profile: VPNProfile, provider: NEPacketTunnelProvider) async throws {
        let quickConfig = try AmneziaAWGConfigExtractor.configurationText(from: profile)
        let tunnelConfiguration = try AWGQuickConfigParser.parse(quickConfig, name: profile.name)

        let adapter = WireGuardAdapter(with: provider) { level, message in
            #if DEBUG
            let prefix = level == .error ? "[AWG:error]" : "[AWG]"
            print("\(prefix) \(message)")
            #endif
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            adapter.start(tunnelConfiguration: tunnelConfiguration) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        self.adapter = adapter
    }

    func stop() async {
        guard let adapter else { return }

        await withCheckedContinuation { continuation in
            adapter.stop { _ in
                continuation.resume()
            }
        }

        self.adapter = nil
    }
}
