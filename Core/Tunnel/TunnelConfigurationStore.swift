import Foundation

enum TunnelConfigurationStore {
    static let profileKey = "RemnantVOP.profile"
    static let runtimeOptionsKey = "RemnantVOP.runtimeOptions"

    static func providerConfiguration(
        for profile: VPNProfile,
        runtimeOptions: TunnelRuntimeOptions = .standard
    ) throws -> [String: Any] {
        let encoder = JSONEncoder()
        return [
            profileKey: try encoder.encode(profile),
            runtimeOptionsKey: try encoder.encode(runtimeOptions)
        ]
    }

    static func profile(from providerConfiguration: [String: Any]?) throws -> VPNProfile {
        guard let data = providerConfiguration?[profileKey] as? Data else {
            throw TunnelConfigurationStoreError.missingProfile
        }
        return try JSONDecoder().decode(VPNProfile.self, from: data)
    }

    static func runtimeOptions(from providerConfiguration: [String: Any]?) -> TunnelRuntimeOptions {
        guard let data = providerConfiguration?[runtimeOptionsKey] as? Data,
              let options = try? JSONDecoder().decode(TunnelRuntimeOptions.self, from: data) else {
            return .standard
        }
        return options
    }
}

enum TunnelConfigurationStoreError: LocalizedError {
    case missingProfile

    var errorDescription: String? {
        "Packet Tunnel не получил профиль подключения."
    }
}
