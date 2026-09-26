import Foundation

enum AmneziaAWGConfigExtractor {
    static func configurationText(from profile: VPNProfile) throws -> String {
        let source = profile.rawConfiguration.trimmingCharacters(in: .whitespacesAndNewlines)

        if looksLikeWGQuick(source) {
            return source
        }

        guard let data = source.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let config = findAWGConfiguration(in: object) else {
            throw AWGConfigurationError.awgConfigurationNotFound
        }

        return config
    }

    private static func findAWGConfiguration(in value: Any) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if looksLikeWGQuick(trimmed) {
                return trimmed
            }

            if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")),
               let data = trimmed.data(using: .utf8),
               let nested = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                return findAWGConfiguration(in: nested)
            }

            return nil
        }

        if let dictionary = value as? [String: Any] {
            if let native = dictionary["config"] as? String,
               looksLikeWGQuick(native) {
                return native
            }

            if looksLikeStructuredAWG(dictionary),
               let generated = makeWGQuick(from: dictionary) {
                return generated
            }

            let priorityKeys = [
                "awg",
                "amnezia-awg",
                "amnezia_awg",
                "last_config",
                "lastConfig",
                "containers",
                "protocols"
            ]

            for key in priorityKeys {
                if let nested = dictionary[key],
                   let match = findAWGConfiguration(in: nested) {
                    return match
                }
            }

            for nested in dictionary.values {
                if let match = findAWGConfiguration(in: nested) {
                    return match
                }
            }

            return nil
        }

        if let array = value as? [Any] {
            for nested in array {
                if let match = findAWGConfiguration(in: nested) {
                    return match
                }
            }
        }

        return nil
    }

    private static func looksLikeWGQuick(_ value: String) -> Bool {
        value.range(of: "[Interface]", options: .caseInsensitive) != nil &&
        value.range(of: "[Peer]", options: .caseInsensitive) != nil
    }

    private static func looksLikeStructuredAWG(_ object: [String: Any]) -> Bool {
        string("client_priv_key", in: object) != nil &&
        string("server_pub_key", in: object) != nil &&
        string("client_ip", in: object) != nil &&
        string("hostName", in: object) != nil &&
        string("port", in: object) != nil
    }

    private static func makeWGQuick(from object: [String: Any]) -> String? {
        guard
            let privateKey = string("client_priv_key", in: object),
            let address = string("client_ip", in: object),
            let publicKey = string("server_pub_key", in: object),
            let host = string("hostName", in: object),
            let port = string("port", in: object)
        else {
            return nil
        }

        var interface: [String] = [
            "[Interface]",
            "Address = \(address)",
            "PrivateKey = \(privateKey)"
        ]

        let dns = ["dns1", "dns2"]
            .compactMap { string($0, in: object) }
            .filter { !$0.isEmpty }

        if !dns.isEmpty {
            interface.append("DNS = \(dns.joined(separator: ", "))")
        }

        if let mtu = string("mtu", in: object), !mtu.isEmpty {
            interface.append("MTU = \(mtu)")
        }

        for key in awgInterfaceKeys {
            if let value = string(key, in: object), !value.isEmpty {
                interface.append("\(key) = \(value)")
            }
        }

        var peer: [String] = [
            "[Peer]",
            "PublicKey = \(publicKey)"
        ]

        if let presharedKey = string("psk_key", in: object), !presharedKey.isEmpty {
            peer.append("PresharedKey = \(presharedKey)")
        }

        let allowed = stringArray("allowed_ips", in: object)
        if !allowed.isEmpty {
            peer.append("AllowedIPs = \(allowed.joined(separator: ", "))")
        }

        peer.append("Endpoint = \(endpoint(host: host, port: port))")

        if let keepAlive = string("persistent_keep_alive", in: object), !keepAlive.isEmpty {
            peer.append("PersistentKeepalive = \(keepAlive)")
        }

        return (interface + [""] + peer).joined(separator: "\n")
    }

    private static let awgInterfaceKeys = [
        "Jc", "Jmin", "Jmax",
        "S1", "S2", "S3", "S4",
        "H1", "H2", "H3", "H4",
        "I1", "I2", "I3", "I4", "I5",
        "HeaderProtectionKey",
        "ContentPaddingAddition",
        "RekeyAfterTime",
        "RekeyTimeout",
        "RejectAfterTime",
        "KeepaliveTimeout",
        "MaxHandshakeAttempts",
        "RandomTrailers",
        "DisableCookies"
    ]

    private static func string(_ key: String, in object: [String: Any]) -> String? {
        switch object[key] {
        case let value as String:
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private static func stringArray(_ key: String, in object: [String: Any]) -> [String] {
        if let values = object[key] as? [Any] {
            return values.compactMap {
                if let string = $0 as? String {
                    return string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let number = $0 as? NSNumber {
                    return number.stringValue
                }
                return nil
            }.filter { !$0.isEmpty }
        }

        if let value = string(key, in: object) {
            return value
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    private static func endpoint(host: String, port: String) -> String {
        if host.contains(":") && !host.hasPrefix("[") {
            return "[\(host)]:\(port)"
        }
        return "\(host):\(port)"
    }
}
