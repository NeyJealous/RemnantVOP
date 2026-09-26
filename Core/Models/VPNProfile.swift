import Foundation

struct VPNProfile: Codable, Identifiable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case amneziaVPNLink
        case shareLink
        case configurationText
        case subscription
    }

    let id: UUID
    var name: String
    var protocolType: TunnelProtocol
    var rawConfiguration: String
    var routing: RoutingProfile
    var source: Source

    init(
        id: UUID = UUID(),
        name: String,
        protocolType: TunnelProtocol,
        rawConfiguration: String,
        routing: RoutingProfile = .fullTunnel,
        source: Source
    ) {
        self.id = id
        self.name = name
        self.protocolType = protocolType
        self.rawConfiguration = rawConfiguration
        self.routing = routing
        self.source = source
    }
}
