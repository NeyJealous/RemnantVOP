import Foundation

enum EngineFactory {
    static func make(for protocolType: TunnelProtocol) -> VPNEngine {
        switch protocolType {
        case .amneziaWG:
            return AWGEngine()
        case .vless, .hysteria2:
            return SingBoxEngine(kind: protocolType)
        }
    }
}
