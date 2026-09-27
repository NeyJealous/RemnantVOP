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
        try await start(
            profile: profile,
            provider: provider,
            runtimeOptions: .standard
        )
    }

    func start(
        profile: VPNProfile,
        provider: NEPacketTunnelProvider,
        runtimeOptions: TunnelRuntimeOptions
    ) async throws {
        if let runtime {
            await runtime.stop()
            self.runtime = nil
        }

        let config = try SingBoxConfigurationBuilder.build(
            for: profile,
            runtimeOptions: runtimeOptions
        )

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
        guard let runtime else { return }
        await runtime.stop()
        self.runtime = nil
    }
}
