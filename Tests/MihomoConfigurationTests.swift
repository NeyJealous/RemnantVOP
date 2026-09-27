import XCTest
@testable import RemnantVOP

final class MihomoConfigurationTests: XCTestCase {
    func testHysteria2ShareLinkCompilesToMihomo() throws {
        let profile = VPNProfile(
            name: "HY2",
            protocolType: .hysteria2,
            rawConfiguration: "hysteria2://secret@example.com:443?sni=edge.example.com&insecure=1&obfs=salamander&obfs-password=mask&upmbps=100&downmbps=250#HY2",
            source: .shareLink
        )

        let text = try MihomoConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        )
        let proxies = try XCTUnwrap(root["proxies"] as? [[String: Any]])
        let proxy = try XCTUnwrap(proxies.first)

        XCTAssertEqual(proxy["type"] as? String, "hysteria2")
        XCTAssertEqual(proxy["server"] as? String, "example.com")
        XCTAssertEqual(proxy["port"] as? Int, 443)
        XCTAssertEqual(proxy["password"] as? String, "secret")
        XCTAssertEqual(proxy["sni"] as? String, "edge.example.com")
        XCTAssertEqual(proxy["skip-cert-verify"] as? Bool, true)
        XCTAssertEqual(proxy["obfs"] as? String, "salamander")
        XCTAssertEqual(proxy["obfs-password"] as? String, "mask")
        XCTAssertEqual(proxy["up"] as? String, "100 Mbps")
        XCTAssertEqual(proxy["down"] as? String, "250 Mbps")
    }

    func testMihomoRoutingFinalMode() throws {
        let routing = RoutingProfile(
            mode: .vpnOnlyForRules,
            rules: [
                RoutingRule(kind: .domainSuffix, value: ".example.com", action: .vpn),
                RoutingRule(kind: .cidr, value: "10.0.0.0/8", action: .direct)
            ]
        )

        let profile = VPNProfile(
            name: "HY2",
            protocolType: .hysteria2,
            rawConfiguration: "hy2://secret@example.com:443",
            routing: routing,
            source: .shareLink
        )

        let text = try MihomoConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        )
        let rules = try XCTUnwrap(root["rules"] as? [String])

        XCTAssertEqual(rules[0], "DOMAIN-SUFFIX,example.com,PROXY")
        XCTAssertEqual(rules[1], "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve")
        XCTAssertEqual(rules.last, "MATCH,DIRECT")
    }

    func testSingBoxJSONSubscriptionConvertsToMihomo() throws {
        let raw = """
        {
          "outbounds": [
            {
              "type": "hysteria2",
              "tag": "hy",
              "server": "hy.example.com",
              "server_port": 8443,
              "password": "pass",
              "up_mbps": 50,
              "down_mbps": 200,
              "obfs": {
                "type": "salamander",
                "password": "obfs-pass"
              },
              "tls": {
                "enabled": true,
                "server_name": "sni.example.com",
                "insecure": false,
                "alpn": ["h3"]
              }
            }
          ]
        }
        """

        let profile = VPNProfile(
            name: "JSON",
            protocolType: .hysteria2,
            rawConfiguration: raw,
            source: .subscription
        )

        let text = try MihomoConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        )
        let proxy = try XCTUnwrap((root["proxies"] as? [[String: Any]])?.first)

        XCTAssertEqual(proxy["server"] as? String, "hy.example.com")
        XCTAssertEqual(proxy["port"] as? Int, 8443)
        XCTAssertEqual(proxy["sni"] as? String, "sni.example.com")
        XCTAssertEqual(proxy["obfs"] as? String, "salamander")
    }
}
