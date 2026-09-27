import Foundation

struct RoutingProfile: Codable, Equatable, Sendable {
    enum Mode: String, Codable, CaseIterable, Hashable, Sendable {
        case fullTunnel
        case vpnOnlyForRules
        case bypassRules
    }

    var mode: Mode
    var rules: [RoutingRule]

    static let fullTunnel = RoutingProfile(mode: .fullTunnel, rules: [])
}

struct RoutingRule: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Hashable, Sendable {
        case domain
        case domainSuffix
        case cidr
        case ip
    }

    enum Action: String, Codable, CaseIterable, Hashable, Sendable {
        case vpn
        case direct
        case block
    }

    let id: UUID
    var kind: Kind
    var value: String
    var action: Action

    init(id: UUID = UUID(), kind: Kind, value: String, action: Action) {
        self.id = id
        self.kind = kind
        self.value = value
        self.action = action
    }
}
