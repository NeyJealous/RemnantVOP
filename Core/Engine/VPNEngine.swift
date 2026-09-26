import Foundation
import NetworkExtension

protocol VPNEngine: AnyObject {
    var kind: TunnelProtocol { get }
    func start(profile: VPNProfile, provider: NEPacketTunnelProvider) async throws
    func stop() async
}

enum VPNEngineError: LocalizedError {
    case coreNotLinked(String)

    var errorDescription: String? {
        switch self {
        case .coreNotLinked(let core):
            return "\(core) ещё не подключён к Packet Tunnel."
        }
    }
}
