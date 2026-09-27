import Foundation

enum VPNProviderDescriptor {
    static let awgBundleIdentifier = "com.neyjealous.RemnantVOP.AWGTunnel"
    static let hysteriaBundleIdentifier = "com.neyjealous.RemnantVOP.HysteriaTunnel"
    static let xrayBundleIdentifier = "com.neyjealous.RemnantVOP.XrayTunnel"

    static func bundleIdentifier(for protocolType: TunnelProtocol) -> String {
        switch protocolType {
        case .amneziaWG:
            return awgBundleIdentifier
        case .hysteria2:
            return hysteriaBundleIdentifier
        case .vless:
            return xrayBundleIdentifier
        }
    }
}
