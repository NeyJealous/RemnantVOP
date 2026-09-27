import Foundation

enum XrayConfigurationBuilder {
    static func build(profile: VPNProfile, tunnelFileDescriptor: Int32) throws -> String {
        guard profile.protocolType == .vless else {
            throw XrayConfigurationError.wrongProtocol
        }

        var proxy = try proxyOutbound(from: profile.rawConfiguration)
        proxy["tag"] = "proxy"

        let direct: [String: Any] = [
            "protocol": "freedom",
            "tag": "direct",
            "settings": [:]
        ]

        let block: [String: Any] = [
            "protocol": "blackhole",
            "tag": "block",
            "settings": [:]
        ]

        var rules = profile.routing.rules.compactMap(makeRule)

        let defaultOutbound: String
        switch profile.routing.mode {
        case .vpnOnlyForRules:
            defaultOutbound = "direct"
        case .fullTunnel, .bypassRules:
            defaultOutbound = "proxy"
        }

        rules.append([
            "type": "field",
            "network": "tcp,udp",
            "outboundTag": defaultOutbound
        ])

        let root: [String: Any] = [
            "log": [
                "loglevel": "warning"
            ],
            "env": [
                "xray.tun.fd": String(tunnelFileDescriptor)
            ],
            "dns": [
                "servers": [
                    "1.1.1.1",
                    "8.8.8.8"
                ],
                "queryStrategy": "UseIP"
            ],
            "inbounds": [[
                "protocol": "tun",
                "tag": "tun-in",
                "settings": [
                    "mtu": 1400
                ],
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"]
                ]
            ]],
            "outbounds": [proxy, direct, block],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": rules
            ]
        ]

        guard JSONSerialization.isValidJSONObject(root) else {
            throw XrayConfigurationError.serializationFailed
        }

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw XrayConfigurationError.serializationFailed
        }
        return text
    }

    private static func proxyOutbound(from source: String) throws -> [String: Any] {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let outbounds = root["outbounds"] as? [[String: Any]],
           let first = outbounds.first {
            return first
        }

        let converted = try XrayBridge.invoke(
            method: "convertShareLinksToXrayJson",
            payload: ["text": trimmed]
        )
        guard let outbounds = converted["outbounds"] as? [[String: Any]],
              let first = outbounds.first
        else {
            throw XrayConfigurationError.noUsableOutbound
        }
        return first
    }

    private static func makeRule(_ rule: RoutingRule) -> [String: Any]? {
        var result: [String: Any] = ["type": "field"]

        switch rule.kind {
        case .domain:
            result["domain"] = ["full:\(rule.value)"]
        case .domainSuffix:
            let value = rule.value.hasPrefix(".") ? String(rule.value.dropFirst()) : rule.value
            result["domain"] = ["domain:\(value)"]
        case .cidr:
            result["ip"] = [rule.value]
        case .ip:
            result["ip"] = [rule.value.contains("/") ? rule.value : "\(rule.value)/32"]
        }

        switch rule.action {
        case .vpn:
            result["outboundTag"] = "proxy"
        case .direct:
            result["outboundTag"] = "direct"
        case .block:
            result["outboundTag"] = "block"
        }

        return result
    }
}

enum XrayConfigurationError: LocalizedError {
    case wrongProtocol
    case noUsableOutbound
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .wrongProtocol:
            return "Xray получил профиль другого протокола."
        case .noUsableOutbound:
            return "В VLESS-профиле не найден рабочий Xray outbound."
        case .serializationFailed:
            return "Не удалось сформировать Xray-конфигурацию."
        }
    }
}
