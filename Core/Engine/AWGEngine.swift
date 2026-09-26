import Foundation
import NetworkExtension

final class AWGEngine: VPNEngine {
    let kind: TunnelProtocol = .amneziaWG

    func start(profile: VPNProfile, provider: NEPacketTunnelProvider) async throws {
        // Phase 1:
        // - map vpn:// JSON or AWG .conf to WireGuardKit
        // - preserve/map AWG 3.1-specific parameters
        // - start amneziawg-apple using the Packet Tunnel provider
        throw VPNEngineError.coreNotLinked("amneziawg-apple")
    }

    func stop() async {
        // Implemented when the AWG adapter is linked.
    }
}
