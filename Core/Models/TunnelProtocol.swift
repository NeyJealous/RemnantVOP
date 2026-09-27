import Foundation

enum TunnelProtocol: String, Codable, CaseIterable, Hashable, Sendable {
    case amneziaWG
    case vless
    case hysteria2

    var displayName: String {
        switch self {
        case .amneziaWG: return "AmneziaWG 3.1"
        case .vless: return "VLESS"
        case .hysteria2: return "Hysteria2"
        }
    }
}
