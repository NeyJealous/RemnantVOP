import Foundation

enum AWGConfigurationError: LocalizedError {
    case awgConfigurationNotFound
    case malformedLine(String)
    case missingInterface
    case missingPrivateKey
    case invalidPrivateKey
    case invalidAddress(String)
    case invalidDNS(String)
    case invalidUInt16(key: String, value: String)
    case invalidHeaderProtectionKey
    case peerMissingPublicKey
    case invalidPublicKey
    case invalidPreSharedKey
    case invalidAllowedIP(String)
    case invalidEndpoint(String)
    case emptyPeers

    var errorDescription: String? {
        switch self {
        case .awgConfigurationNotFound:
            return "В vpn:// не найдена конфигурация AmneziaWG."
        case .malformedLine(let line):
            return "Некорректная строка AWG-конфигурации: \(line)"
        case .missingInterface:
            return "В AWG-конфигурации отсутствует секция [Interface]."
        case .missingPrivateKey:
            return "В AWG-конфигурации отсутствует PrivateKey."
        case .invalidPrivateKey:
            return "PrivateKey AWG имеет некорректный формат."
        case .invalidAddress(let value):
            return "Некорректный Address в AWG: \(value)"
        case .invalidDNS(let value):
            return "Некорректный DNS в AWG: \(value)"
        case .invalidUInt16(let key, let value):
            return "Некорректное значение \(key) в AWG: \(value)"
        case .invalidHeaderProtectionKey:
            return "HeaderProtectionKey AWG 3.1 имеет некорректный формат."
        case .peerMissingPublicKey:
            return "В секции [Peer] отсутствует PublicKey."
        case .invalidPublicKey:
            return "PublicKey AWG имеет некорректный формат."
        case .invalidPreSharedKey:
            return "PresharedKey AWG имеет некорректный формат."
        case .invalidAllowedIP(let value):
            return "Некорректный AllowedIPs в AWG: \(value)"
        case .invalidEndpoint(let value):
            return "Некорректный Endpoint в AWG: \(value)"
        case .emptyPeers:
            return "В AWG-конфигурации отсутствует секция [Peer]."
        }
    }
}
