import Foundation
import NetworkExtension

final class SingBoxEngine: VPNEngine {
    let kind: TunnelProtocol

    init(kind: TunnelProtocol) {
        precondition(kind == .vless || kind == .hysteria2)
        self.kind = kind
    }

    func start(profile: VPNProfile, provider: NEPacketTunnelProvider) async throws {
        // Phase 2:
        // - compile VPNProfile + RoutingProfile to sing-box JSON
        // - start the iOS sing-box TUN backend
        // - VLESS and Hysteria2 share this engine
        throw VPNEngineError.coreNotLinked("sing-box")
    }

    func stop() async {
        // Implemented when sing-box is linked.
    }
}
