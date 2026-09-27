import Foundation

enum SingBoxConfigurationBuilder {
    static func build(
        for profile: VPNProfile,
        runtimeOptions: TunnelRuntimeOptions = .standard
    ) throws -> String {
        var proxy = try proxyOutbound(from: profile)
        proxy["tag"] = "proxy"

        let dns = dnsObject(runtimeOptions)

        let root: [String: Any] = [
            "log": [
                "level": runtimeOptions.diagnosticsLogging ? "debug" : "info",
                "timestamp": true
            ],
            "dns": dns,
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

    private static func proxyOutbound(from profile: VPNProfile) throws -> [String: Any] {
        let raw = profile.rawConfiguration.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.hasPrefix("{"),
           let data = raw.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let outbounds = root["outbounds"] as? [[String: Any]],
           let outbound = outbounds.first(where: {
               ($0["type"] as? String)?.lowercased() == "hysteria2"
           }) {
            return outbound
        }

        return try SingBoxShareLinkParser.outbound(from: profile)
    }

    private static func dnsObject(_ runtimeOptions: TunnelRuntimeOptions) -> [String: Any] {
        if let server = runtimeOptions.dnsServers.first, !server.isEmpty {
            return [
                "servers": [
                    [
                        "type": "udp",
                        "tag": "remote-dns",
                        "server": server
                    ]
                ],
                "final": "remote-dns",
                "reverse_mapping": true
            ]
        }

        return [
            "servers": [
                [
                    "type": "local",
                    "tag": "local-dns"
                ]
            ],
            "final": "local-dns",
            "reverse_mapping": true
        ]
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
        case .cidr:
            result["ip_cidr"] = [rule.value]
        case .ip:
            result["ip_cidr"] = [rule.value.contains("/") ? rule.value : "\(rule.value)/32"]
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
