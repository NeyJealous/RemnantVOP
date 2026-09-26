import Foundation
import WireGuardKit

enum AWGQuickConfigParser {
    private enum Section {
        case none
        case interface
        case peer
    }

    static func parse(_ source: String, name: String? = nil) throws -> TunnelConfiguration {
        var section: Section = .none
        var interfaceAttributes: [String: [String]]?
        var currentAttributes: [String: [String]] = [:]
        var peerAttributes: [[String: [String]]] = []

        func flushCurrentSection() {
            switch section {
            case .interface:
                interfaceAttributes = currentAttributes
            case .peer:
                peerAttributes.append(currentAttributes)
            case .none:
                break
            }
            currentAttributes = [:]
        }

        for rawLine in source.components(separatedBy: .newlines) {
            let uncommented = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? rawLine
            let line = uncommented.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            switch line.lowercased() {
            case "[interface]":
                flushCurrentSection()
                section = .interface
                continue
            case "[peer]":
                flushCurrentSection()
                section = .peer
                continue
            default:
                break
            }

            guard let separator = line.firstIndex(of: "=") else {
                throw AWGConfigurationError.malformedLine(line)
            }

            let key = line[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard section != .none, !key.isEmpty else {
                throw AWGConfigurationError.malformedLine(line)
            }

            currentAttributes[key, default: []].append(value)
        }

        flushCurrentSection()

        guard let interfaceAttributes else {
            throw AWGConfigurationError.missingInterface
        }

        let interface = try makeInterface(from: interfaceAttributes)
        let peers = try peerAttributes.map(makePeer(from:))

        guard !peers.isEmpty else {
            throw AWGConfigurationError.emptyPeers
        }

        return TunnelConfiguration(name: name, interface: interface, peers: peers)
    }

    private static func makeInterface(from values: [String: [String]]) throws -> InterfaceConfiguration {
        guard let privateKeyString = first("privatekey", in: values) else {
            throw AWGConfigurationError.missingPrivateKey
        }
        guard let privateKey = PrivateKey(base64Key: privateKeyString) else {
            throw AWGConfigurationError.invalidPrivateKey
        }

        var interface = InterfaceConfiguration(privateKey: privateKey)

        if let value = first("listenport", in: values) {
            interface.listenPort = try uint16(value, key: "ListenPort")
        }

        interface.addresses = try flattened("address", in: values).map {
            guard let address = IPAddressRange(from: $0) else {
                throw AWGConfigurationError.invalidAddress($0)
            }
            return address
        }

        for value in flattened("dns", in: values) {
            if let dns = DNSServer(from: value) {
                interface.dns.append(dns)
            } else if !value.isEmpty {
                interface.dnsSearch.append(value)
            } else {
                throw AWGConfigurationError.invalidDNS(value)
            }
        }

        if let value = first("mtu", in: values) {
            interface.mtu = try uint16(value, key: "MTU")
        }

        if let value = first("jc", in: values) {
            interface.junkPacketCount = try uint16(value, key: "Jc")
        }
        if let value = first("jmin", in: values) {
            interface.junkPacketMinSize = try uint16(value, key: "Jmin")
        }
        if let value = first("jmax", in: values) {
            interface.junkPacketMaxSize = try uint16(value, key: "Jmax")
        }
        if let value = first("s1", in: values) {
            interface.initPacketJunkSize = try uint16(value, key: "S1")
        }
        if let value = first("s2", in: values) {
            interface.responsePacketJunkSize = try uint16(value, key: "S2")
        }
        if let value = first("s3", in: values) {
            interface.cookieReplyPacketJunkSize = try uint16(value, key: "S3")
        }
        if let value = first("s4", in: values) {
            interface.transportPacketJunkSize = try uint16(value, key: "S4")
        }

        interface.initPacketMagicHeader = first("h1", in: values)
        interface.responsePacketMagicHeader = first("h2", in: values)
        interface.underloadPacketMagicHeader = first("h3", in: values)
        interface.transportPacketMagicHeader = first("h4", in: values)

        interface.specialJunk1 = first("i1", in: values)
        interface.specialJunk2 = first("i2", in: values)
        interface.specialJunk3 = first("i3", in: values)
        interface.specialJunk4 = first("i4", in: values)
        interface.specialJunk5 = first("i5", in: values)

        if let value = first("headerprotectionkey", in: values) {
            guard let key = PrivateKey(base64Key: value) else {
                throw AWGConfigurationError.invalidHeaderProtectionKey
            }
            interface.headerProtectionKey = key
        }

        interface.contentPaddingAddition = first("contentpaddingaddition", in: values)
        interface.rekeyAfterTime = first("rekeyaftertime", in: values)
        interface.rekeyTimeout = first("rekeytimeout", in: values)
        interface.rejectAfterTime = first("rejectaftertime", in: values)
        interface.keepaliveTimeout = first("keepalivetimeout", in: values)
        interface.maxHandshakeAttempts = first("maxhandshakeattempts", in: values)
        interface.randomTrailers = first("randomtrailers", in: values)
        interface.disableCookies = first("disablecookies", in: values)

        return interface
    }

    private static func makePeer(from values: [String: [String]]) throws -> PeerConfiguration {
        guard let publicKeyString = first("publickey", in: values) else {
            throw AWGConfigurationError.peerMissingPublicKey
        }
        guard let publicKey = PublicKey(base64Key: publicKeyString) else {
            throw AWGConfigurationError.invalidPublicKey
        }

        var peer = PeerConfiguration(publicKey: publicKey)

        if let value = first("presharedkey", in: values) {
            guard let key = PreSharedKey(base64Key: value) else {
                throw AWGConfigurationError.invalidPreSharedKey
            }
            peer.preSharedKey = key
        }

        peer.allowedIPs = try flattened("allowedips", in: values).map {
            guard let range = IPAddressRange(from: $0) else {
                throw AWGConfigurationError.invalidAllowedIP($0)
            }
            return range
        }

        if let value = first("endpoint", in: values) {
            guard let endpoint = Endpoint(from: value) else {
                throw AWGConfigurationError.invalidEndpoint(value)
            }
            peer.endpoint = endpoint
        }

        peer.persistentKeepAlive = first("persistentkeepalive", in: values)
        return peer
    }

    private static func first(_ key: String, in values: [String: [String]]) -> String? {
        values[key]?.last?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func flattened(_ key: String, in values: [String: [String]]) -> [String] {
        (values[key] ?? [])
            .flatMap { $0.split(separator: ",").map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func uint16(_ value: String, key: String) throws -> UInt16 {
        guard let number = UInt16(value) else {
            throw AWGConfigurationError.invalidUInt16(key: key, value: value)
        }
        return number
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
