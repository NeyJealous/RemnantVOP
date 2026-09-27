import Foundation

enum SingBoxConfigurationBuilder {
    static func build(for profile: VPNProfile) throws -> String {
        let proxy = try SingBoxShareLinkParser.outbound(from: profile)

        let root: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true
            ],
            "dns": [
                "servers": [
                    [
                        "type": "local",
                        "tag": "local-dns"
                    ]
                ],
                "final": "local-dns",
                "reverse_mapping": true
            ],
            "inbounds": [
                [
                    "type": "tun",
                    "tag": "tun-in",
                    "address": [
                        "172.19.0.1/30",
                        "fdfe:dcba:9876::1/126"
                    ],
                    "mtu": 1400,
                    "dns_mode": "hijack",
                    "dns_address": [
                        "172.19.0.2",
                        "fdfe:dcba:9876::2"
                    ],
                    "auto_route": true,
                    "stack": "mixed"
                ]
            ],
            "outbounds": [
                proxy,
                [
                    "type": "direct",
                    "tag": "direct"
                ]
            ],
            "route": routeObject(profile.routing)
        ]

        guard JSONSerialization.isValidJSONObject(root) else {
            throw SingBoxConfigurationError.serializationFailed
        }

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw SingBoxConfigurationError.serializationFailed
        }
        return text
    }

    private static func routeObject(_ profile: RoutingProfile) -> [String: Any] {
        let final: String
        switch profile.mode {
        case .fullTunnel, .bypassRules:
            final = "proxy"
        case .vpnOnlyForRules:
            final = "direct"
        }

        return [
            "auto_detect_interface": true,
            "rules": profile.rules.map(routeRule),
            "final": final
        ]
    }

    private static func routeRule(_ rule: RoutingRule) -> [String: Any] {
        var result: [String: Any] = [:]

        switch rule.kind {
        case .domain:
            result["domain"] = [rule.value]
        case .domainSuffix:
            result["domain_suffix"] = [rule.value]
        case .cidr, .ip:
            result["ip_cidr"] = [rule.value]
        }

        switch rule.action {
        case .vpn:
            result["action"] = "route"
            result["outbound"] = "proxy"
        case .direct:
            result["action"] = "route"
            result["outbound"] = "direct"
        case .block:
            result["action"] = "reject"
        }

        return result
    }
}
