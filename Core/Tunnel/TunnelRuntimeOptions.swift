import Foundation

struct TunnelRuntimeOptions: Codable, Equatable, Sendable {
    var dnsServers: [String]
    var diagnosticsLogging: Bool

    static let standard = TunnelRuntimeOptions(
        dnsServers: [],
        diagnosticsLogging: false
    )
}
