import Foundation

enum SingBoxShareLinkParser {
    static func outbound(from profile: VPNProfile) throws -> [String: Any] {
        switch profile.protocolType {
        case .vless:
            return try vlessOutbound(from: profile.rawConfiguration)
        case .hysteria2:
            return try hysteria2Outbound(from: profile.rawConfiguration)
        case .amneziaWG:
            throw SingBoxConfigurationError.invalidShareLink
        }
    }

    private static func vlessOutbound(from link: String) throws -> [String: Any] {
        guard let components = URLComponents(string: link),
              components.scheme?.lowercased() == "vless" else {
            throw SingBoxConfigurationError.invalidShareLink
        }
        guard let host = components.host, !host.isEmpty else {
            throw SingBoxConfigurationError.missingHost
        }
        guard let port = components.port else {
            throw SingBoxConfigurationError.missingPort
        }
        guard let rawUUID = components.user, !rawUUID.isEmpty else {
            throw SingBoxConfigurationError.missingCredential
        }

        let query = queryMap(components)
        var outbound: [String: Any] = [
            "type": "vless",
            "tag": "proxy",
            "server": host,
            "server_port": port,
            "uuid": rawUUID.removingPercentEncoding ?? rawUUID
        ]

        if let flow = query["flow"], !flow.isEmpty {
            outbound["flow"] = flow
        }
        if let packetEncoding = query["packetencoding"] ?? query["packet_encoding"], !packetEncoding.isEmpty {
            outbound["packet_encoding"] = packetEncoding
        }

        let security = (query["security"] ?? "none").lowercased()
        switch security {
        case "", "none":
            break
        case "tls", "reality":
            var tls: [String: Any] = [
                "enabled": true,
                "server_name": query["sni"] ?? query["servername"] ?? host
            ]
            if truthy(query["allowinsecure"] ?? query["insecure"]) {
                tls["insecure"] = true
            }
            if let alpn = query["alpn"] {
                let values = splitList(alpn)
                if !values.isEmpty {
                    tls["alpn"] = values
                }
            }
            if let fingerprint = query["fp"], !fingerprint.isEmpty {
                tls["utls"] = [
                    "enabled": true,
                    "fingerprint": fingerprint
                ]
            }
            if security == "reality" {
                guard let publicKey = query["pbk"] ?? query["publickey"], !publicKey.isEmpty else {
                    throw SingBoxConfigurationError.invalidShareLink
                }
                var reality: [String: Any] = [
                    "enabled": true,
                    "public_key": publicKey
                ]
                if let shortID = query["sid"] ?? query["shortid"], !shortID.isEmpty {
                    reality["short_id"] = shortID
                }
                tls["reality"] = reality
            }
            outbound["tls"] = tls
        default:
            throw SingBoxConfigurationError.unsupportedSecurity(security)
        }

        let transportType = (query["type"] ?? "tcp").lowercased()
        switch transportType {
        case "", "tcp", "raw":
            break
        case "ws", "websocket":
            var transport: [String: Any] = ["type": "ws"]
            if let path = query["path"], !path.isEmpty {
                transport["path"] = path
            }
            if let hostHeader = query["host"], !hostHeader.isEmpty {
                transport["headers"] = ["Host": hostHeader]
            }
            outbound["transport"] = transport
        case "grpc":
            var transport: [String: Any] = ["type": "grpc"]
            if let serviceName = query["servicename"] ?? query["service_name"], !serviceName.isEmpty {
                transport["service_name"] = serviceName
            }
            outbound["transport"] = transport
        case "httpupgrade":
            var transport: [String: Any] = ["type": "httpupgrade"]
            if let path = query["path"], !path.isEmpty {
                transport["path"] = path
            }
            if let hostHeader = query["host"], !hostHeader.isEmpty {
                transport["host"] = hostHeader
            }
            outbound["transport"] = transport
        case "http", "h2":
            var transport: [String: Any] = ["type": "http"]
            if let path = query["path"], !path.isEmpty {
                transport["path"] = path
            }
            if let hostHeader = query["host"], !hostHeader.isEmpty {
                transport["host"] = splitList(hostHeader)
            }
            outbound["transport"] = transport
        case "quic":
            outbound["transport"] = ["type": "quic"]
        case "xhttp", "splithttp":
            throw SingBoxConfigurationError.unsupportedVLESSTransport(transportType)
        default:
            throw SingBoxConfigurationError.unsupportedVLESSTransport(transportType)
        }

        return outbound
    }

    private static func hysteria2Outbound(from link: String) throws -> [String: Any] {
        guard let components = URLComponents(string: link),
              let scheme = components.scheme?.lowercased(),
              scheme == "hysteria2" || scheme == "hy2" else {
            throw SingBoxConfigurationError.invalidShareLink
        }
        guard let host = components.host, !host.isEmpty else {
            throw SingBoxConfigurationError.missingHost
        }
        guard let port = components.port else {
            throw SingBoxConfigurationError.missingPort
        }
        guard let password = rawUserInfo(in: link), !password.isEmpty else {
            throw SingBoxConfigurationError.missingCredential
        }

        let query = queryMap(components)
        var tls: [String: Any] = [
            "enabled": true,
            "server_name": query["sni"] ?? host
        ]
        if truthy(query["insecure"]) {
            tls["insecure"] = true
        }
        if let alpn = query["alpn"] {
            let values = splitList(alpn)
            if !values.isEmpty {
                tls["alpn"] = values
            }
        }

        var outbound: [String: Any] = [
            "type": "hysteria2",
            "tag": "proxy",
            "server": host,
            "server_port": port,
            "password": password,
            "tls": tls
        ]

        if let ports = query["mport"] ?? query["ports"], !ports.isEmpty {
            outbound["server_ports"] = splitList(ports)
        }
        if let hop = query["hopinterval"] ?? query["hop_interval"], !hop.isEmpty {
            outbound["hop_interval"] = hop
        }
        if let up = Int(query["upmbps"] ?? query["up_mbps"] ?? "") {
            outbound["up_mbps"] = up
        }
        if let down = Int(query["downmbps"] ?? query["down_mbps"] ?? "") {
            outbound["down_mbps"] = down
        }

        if let obfsType = query["obfs"], !obfsType.isEmpty {
            var obfs: [String: Any] = ["type": obfsType]
            if let obfsPassword = query["obfs-password"] ?? query["obfs_password"], !obfsPassword.isEmpty {
                obfs["password"] = obfsPassword
            }
            outbound["obfs"] = obfs
        }

        return outbound
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
}
