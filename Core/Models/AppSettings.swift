import Foundation

enum ProtocolSelectionMode: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case vless
    case hysteria2
    case amneziaWG

    var title: String {
        switch self {
        case .automatic: return "Авто"
        case .vless: return "VLESS"
        case .hysteria2: return "Hysteria2"
        case .amneziaWG: return "AWG 3.1"
        }
    }

    var protocolType: TunnelProtocol? {
        switch self {
        case .automatic: return nil
        case .vless: return .vless
        case .hysteria2: return .hysteria2
        case .amneziaWG: return .amneziaWG
        }
    }
}

enum DNSMode: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case system
    case cloudflare
    case google
    case adguard
    case custom

    var title: String {
        switch self {
        case .automatic: return "Автоматически"
        case .system: return "Системный"
        case .cloudflare: return "Cloudflare"
        case .google: return "Google"
        case .adguard: return "AdGuard"
        case .custom: return "Собственный"
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var protocolMode: ProtocolSelectionMode
    var fallbackOrder: [TunnelProtocol]
    var killSwitch: Bool
    var autoReconnect: Bool
    var autoConnect: Bool
    var dnsMode: DNSMode
    var customDNSServers: [String]
    var hideConfigurationSecrets: Bool
    var diagnosticsLogging: Bool

    var dnsServers: [String] {
        switch dnsMode {
        case .automatic, .system:
            return []
        case .cloudflare:
            return ["1.1.1.1", "1.0.0.1"]
        case .google:
            return ["8.8.8.8", "8.8.4.4"]
        case .adguard:
            return ["94.140.14.14", "94.140.15.15"]
        case .custom:
            return customDNSServers
        }
    }

    static let standard = AppSettings(
        protocolMode: .automatic,
        fallbackOrder: [.vless, .hysteria2, .amneziaWG],
        killSwitch: false,
        autoReconnect: true,
        autoConnect: false,
        dnsMode: .automatic,
        customDNSServers: [],
        hideConfigurationSecrets: true,
        diagnosticsLogging: false
    )
}
