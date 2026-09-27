import Foundation

enum MihomoConfigurationBuilder {
    static func build(
        for profile: VPNProfile,
        runtimeOptions: TunnelRuntimeOptions = .standard
    ) throws -> String {
        guard profile.protocolType == .hysteria2 else {
            throw MihomoConfigurationError.wrongProtocol
        }

        var proxy = try hysteria2Proxy(from: profile.rawConfiguration)
        proxy["name"] = "REMNANT_PROXY"
        proxy["type"] = "hysteria2"

        let dnsServers = runtimeOptions.dnsServers.isEmpty
            ? ["1.1.1.1", "8.8.8.8"]
            : runtimeOptions.dnsServers

        let root: [String: Any] = [
            "mode": "rule",
            "log-level": runtimeOptions.diagnosticsLogging ? "debug" : "warning",
            "allow-lan": false,
            "ipv6": true,
            "dns": [
                "enable": true,
                "ipv6": true,
                "enhanced-mode": "fake-ip",
                "nameserver": dnsServers
            ],
            "proxies": [proxy],
            "proxy-groups": [[
                "name": "PROXY",
                "type": "select",
                "proxies": ["REMNANT_PROXY"]
            ]],
            "rules": routeRules(profile.routing)
        ]

        guard JSONSerialization.isValidJSONObject(root) else {
            throw MihomoConfigurationError.serializationFailed
        }

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw MihomoConfigurationError.serializationFailed
        }
        return text
    }

    private static func hysteria2Proxy(from rawConfiguration: String) throws -> [String: Any] {
        let raw = rawConfiguration.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.hasPrefix("{") {
            return try hysteria2ProxyFromJSON(raw)
        }

        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              scheme == "hysteria2" || scheme == "hy2" else {
            throw MihomoConfigurationError.invalidShareLink
        }
        guard let host = components.host, !host.isEmpty else {
            throw MihomoConfigurationError.missingHost
        }
        guard let port = components.port else {
            throw MihomoConfigurationError.missingPort
        }
        guard let password = rawUserInfo(in: raw), !password.isEmpty else {
            throw MihomoConfigurationError.missingPassword
        }

        let query = queryMap(components)
        var proxy: [String: Any] = [
            "server": host,
            "port": port,
            "password": password,
            "sni": query["sni"] ?? host,
            "skip-cert-verify": truthy(query["insecure"] ?? query["skip-cert-verify"])
        ]

        if let ports = query["mport"] ?? query["ports"], !ports.isEmpty {
            proxy["ports"] = ports
        }
        if let hop = query["hopinterval"] ?? query["hop-interval"] ?? query["hop_interval"],
           !hop.isEmpty {
            proxy["hop-interval"] = normalizedHopInterval(hop)
        }
        if let up = bandwidth(query["upmbps"] ?? query["up_mbps"] ?? query["up"]) {
            proxy["up"] = up
        }
        if let down = bandwidth(query["downmbps"] ?? query["down_mbps"] ?? query["down"]) {
            proxy["down"] = down
        }

        if let obfs = query["obfs"], !obfs.isEmpty {
            proxy["obfs"] = obfs
            if let password = query["obfs-password"] ?? query["obfspassword"] ?? query["obfs_password"],
               !password.isEmpty {
                proxy["obfs-password"] = password
            }
        }

        if let alpn = query["alpn"] {
            let values = splitList(alpn)
            if !values.isEmpty {
                proxy["alpn"] = values
            }
        }

        if let fingerprint = query["pinsha256"] ?? query["fingerprint"],
           !fingerprint.isEmpty {
            proxy["fingerprint"] = fingerprint
        }

        return proxy
    }

    private static func hysteria2ProxyFromJSON(_ raw: String) throws -> [String: Any] {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MihomoConfigurationError.invalidJSON
        }

        let outbound: [String: Any]?
        if let outbounds = object["outbounds"] as? [[String: Any]] {
            outbound = outbounds.first {
                ($0["type"] as? String)?.lowercased() == "hysteria2"
            }
        } else if (object["type"] as? String)?.lowercased() == "hysteria2" {
            outbound = object
        } else {
            outbound = nil
        }

        guard let outbound else {
            throw MihomoConfigurationError.missingHysteria2Outbound
        }
        guard let server = outbound["server"] as? String, !server.isEmpty else {
            throw MihomoConfigurationError.missingHost
        }
        guard let port = integer(outbound["server_port"] ?? outbound["port"]) else {
            throw MihomoConfigurationError.missingPort
        }
        guard let password = outbound["password"] as? String, !password.isEmpty else {
            throw MihomoConfigurationError.missingPassword
        }

        var proxy: [String: Any] = [
            "server": server,
            "port": port,
            "password": password
        ]

        if let ports = outbound["server_ports"] as? [String], !ports.isEmpty {
            proxy["ports"] = ports.joined(separator: ",")
        } else if let ports = outbound["ports"] as? String, !ports.isEmpty {
            proxy["ports"] = ports
        }

        if let hop = string(outbound["hop_interval"] ?? outbound["hop-interval"]), !hop.isEmpty {
            proxy["hop-interval"] = normalizedHopInterval(hop)
        }
        if let up = integer(outbound["up_mbps"] ?? outbound["up"]) {
            proxy["up"] = "\(up) Mbps"
        }
        if let down = integer(outbound["down_mbps"] ?? outbound["down"]) {
            proxy["down"] = "\(down) Mbps"
        }

        if let obfs = outbound["obfs"] as? [String: Any],
           let type = obfs["type"] as? String, !type.isEmpty {
            proxy["obfs"] = type
            if let value = obfs["password"] as? String, !value.isEmpty {
                proxy["obfs-password"] = value
            }
        }

        if let tls = outbound["tls"] as? [String: Any] {
            proxy["sni"] = (tls["server_name"] as? String) ?? server
            proxy["skip-cert-verify"] = (tls["insecure"] as? Bool) ?? false
            if let alpn = tls["alpn"] as? [String], !alpn.isEmpty {
                proxy["alpn"] = alpn
            }
        } else {
            proxy["sni"] = server
            proxy["skip-cert-verify"] = false
        }

        return proxy
    }

    private static func routeRules(_ routing: RoutingProfile) -> [String] {
        var result = routing.rules.map { rule -> String in
            let target: String
            switch rule.action {
            case .vpn: target = "PROXY"
            case .direct: target = "DIRECT"
            case .block: target = "REJECT"
            }

            switch rule.kind {
            case .domain:
                return "DOMAIN,\(rule.value),\(target)"
            case .domainSuffix:
                let suffix = rule.value.hasPrefix(".")
                    ? String(rule.value.dropFirst())
                    : rule.value
                return "DOMAIN-SUFFIX,\(suffix),\(target)"
            case .cidr:
                let type = rule.value.contains(":") ? "IP-CIDR6" : "IP-CIDR"
                return "\(type),\(rule.value),\(target),no-resolve"
            case .ip:
                let cidr: String
                if rule.value.contains("/") {
                    cidr = rule.value
                } else if rule.value.contains(":") {
                    cidr = "\(rule.value)/128"
                } else {
                    cidr = "\(rule.value)/32"
                }
                let type = cidr.contains(":") ? "IP-CIDR6" : "IP-CIDR"
                return "\(type),\(cidr),\(target),no-resolve"
            }
        }

        switch routing.mode {
        case .fullTunnel, .bypassRules:
            result.append("MATCH,PROXY")
        case .vpnOnlyForRules:
            result.append("MATCH,DIRECT")
        }
        return result
    }

    private static func queryMap(_ components: URLComponents) -> [String: String] {
        var result: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard let value = item.value else { continue }
            result[item.name.lowercased()] = value
        }
        return result
    }

    private static func rawUserInfo(in link: String) -> String? {
        guard let schemeRange = link.range(of: "://") else { return nil }
        let remainder = link[schemeRange.upperBound...]
        guard let at = remainder.lastIndex(of: "@") else { return nil }
        let value = String(remainder[..<at])
        return value.removingPercentEncoding ?? value
    }

    private static func truthy(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private static func splitList(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalizedHopInterval(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("s"),
           trimmed.dropLast().allSatisfy({ $0.isNumber }) {
            return String(trimmed.dropLast())
        }
        return trimmed
    }

    private static func bandwidth(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if Int(trimmed) != nil {
            return "\(trimmed) Mbps"
        }
        return trimmed
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }
}

enum MihomoConfigurationError: LocalizedError {
    case wrongProtocol
    case invalidShareLink
    case invalidJSON
    case missingHost
    case missingPort
    case missingPassword
    case missingHysteria2Outbound
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .wrongProtocol:
            return "Mihomo получил профиль другого протокола."
        case .invalidShareLink:
            return "Некорректная ссылка Hysteria2."
        case .invalidJSON:
            return "Некорректная JSON-конфигурация Hysteria2."
        case .missingHost:
            return "В Hysteria2 отсутствует адрес сервера."
        case .missingPort:
            return "В Hysteria2 отсутствует порт сервера."
        case .missingPassword:
            return "В Hysteria2 отсутствует пароль."
        case .missingHysteria2Outbound:
            return "В конфигурации не найден Hysteria2 outbound."
        case .serializationFailed:
            return "Не удалось сформировать конфигурацию Mihomo."
        }
    }
}
