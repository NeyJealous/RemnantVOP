import Foundation

enum ProfileImportResult: Equatable {
    case profile(VPNProfile)
    case subscription(URL)
}

struct ProfileImporter {
    func parse(_ input: String) throws -> ProfileImportResult {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw ProfileImportError.emptyInput
        }

        let lowercased = value.lowercased()

        if lowercased.hasPrefix("vpn://") {
            let json = try AmneziaVPNLinkDecoder.decode(value)
            let name = AmneziaVPNLinkDecoder.suggestedName(from: json) ?? "AmneziaVPN"
            return .profile(
                VPNProfile(
                    name: name,
                    protocolType: .amneziaWG,
                    rawConfiguration: json,
                    source: .amneziaVPNLink
                )
            )
        }

        if lowercased.hasPrefix("vless://") {
            return .profile(
                VPNProfile(
                    name: shareLinkName(value, fallback: "VLESS"),
                    protocolType: .vless,
                    rawConfiguration: value,
                    source: .shareLink
                )
            )
        }

        if lowercased.hasPrefix("hysteria2://") || lowercased.hasPrefix("hy2://") {
            return .profile(
                VPNProfile(
                    name: shareLinkName(value, fallback: "Hysteria2"),
                    protocolType: .hysteria2,
                    rawConfiguration: value,
                    source: .shareLink
                )
            )
        }

        if lowercased.hasPrefix("https://") || lowercased.hasPrefix("http://") {
            guard let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  url.host != nil else {
                throw ProfileImportError.invalidURL
            }
            return .subscription(url)
        }

        if value.contains("[Interface]") && value.contains("[Peer]") {
            return .profile(
                VPNProfile(
                    name: "AmneziaWG",
                    protocolType: .amneziaWG,
                    rawConfiguration: value,
                    source: .configurationText
                )
            )
        }

        throw ProfileImportError.unsupportedFormat
    }

    private func shareLinkName(_ value: String, fallback: String) -> String {
        if let components = URLComponents(string: value),
           let fragment = components.fragment,
           !fragment.isEmpty {
            return fragment.removingPercentEncoding ?? fragment
        }
        return fallback
    }
}
