import Foundation

enum TunnelConfigurationStore {
    static let profileKey = "RemnantVOP.profile"

    static func providerConfiguration(for profile: VPNProfile) throws -> [String: Any] {
        let data = try JSONEncoder().encode(profile)
        return [profileKey: data]
    }

    static func profile(from providerConfiguration: [String: Any]?) throws -> VPNProfile {
        guard let data = providerConfiguration?[profileKey] as? Data else {
            throw TunnelConfigurationStoreError.missingProfile
        }
        return try JSONDecoder().decode(VPNProfile.self, from: data)
    }
}

enum TunnelConfigurationStoreError: LocalizedError {
    case missingProfile

    var errorDescription: String? {
        "Packet Tunnel не получил профиль подключения."
    }
}
