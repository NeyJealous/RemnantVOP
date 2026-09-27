import Foundation
import Libbox
import NetworkExtension

final class SingBoxEngine: VPNEngine {
    let kind: TunnelProtocol

    private var runtime: SingBoxRuntime?

    init(kind: TunnelProtocol) {
        precondition(kind == .vless || kind == .hysteria2)
        self.kind = kind
    }

    func start(profile: VPNProfile, provider: NEPacketTunnelProvider) async throws {
        let config = try SingBoxConfigurationBuilder.build(for: profile)

        var validationError: NSError?
        LibboxCheckConfig(config, &validationError)
        if let validationError {
            throw validationError
        }

        let runtime = SingBoxRuntime(provider: provider)
        try runtime.start(configContent: config)
        self.runtime = runtime
    }

    func stop() async {
        runtime?.stop()
        runtime = nil
    }
}
