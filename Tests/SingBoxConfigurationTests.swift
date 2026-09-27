import XCTest
@testable import RemnantVOP

final class SingBoxConfigurationTests: XCTestCase {
    func testVLESSRealityVision() throws {
        let link = "vless://00000000-0000-0000-0000-000000000000@example.com:443?security=reality&sni=www.microsoft.com&fp=chrome&pbk=public-key&sid=abcd&flow=xtls-rprx-vision&type=tcp#Main"
        let profile = VPNProfile(
            name: "Main",
            protocolType: .vless,
            rawConfiguration: link,
            source: .shareLink
        )

        let json = try SingBoxConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let outbounds = try XCTUnwrap(root["outbounds"] as? [[String: Any]])
        let proxy = try XCTUnwrap(outbounds.first)
        XCTAssertEqual(proxy["type"] as? String, "vless")
        XCTAssertEqual(proxy["flow"] as? String, "xtls-rprx-vision")

        let tls = try XCTUnwrap(proxy["tls"] as? [String: Any])
        XCTAssertEqual(tls["server_name"] as? String, "www.microsoft.com")
        let reality = try XCTUnwrap(tls["reality"] as? [String: Any])
        XCTAssertEqual(reality["public_key"] as? String, "public-key")
    }

    func testVLESSWebSocket() throws {
        let link = "vless://00000000-0000-0000-0000-000000000000@example.com:443?security=tls&sni=example.com&type=ws&path=%2Fws&host=cdn.example.com"
        let profile = VPNProfile(name: "WS", protocolType: .vless, rawConfiguration: link, source: .shareLink)

        let json = try SingBoxConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let outbounds = try XCTUnwrap(root["outbounds"] as? [[String: Any]])
        let transport = try XCTUnwrap(outbounds[0]["transport"] as? [String: Any])
        XCTAssertEqual(transport["type"] as? String, "ws")
        XCTAssertEqual(transport["path"] as? String, "/ws")
    }

    func testVLESSXHTTPFailsExplicitly() {
        let link = "vless://00000000-0000-0000-0000-000000000000@example.com:443?security=reality&pbk=key&type=xhttp"
        let profile = VPNProfile(name: "XHTTP", protocolType: .vless, rawConfiguration: link, source: .shareLink)

        XCTAssertThrowsError(try SingBoxConfigurationBuilder.build(for: profile)) { error in
            guard case SingBoxConfigurationError.unsupportedVLESSTransport("xhttp") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testHysteria2Salamander() throws {
        let link = "hysteria2://secret@example.com:443?sni=example.com&obfs=salamander&obfs-password=mask&upmbps=100&downmbps=250#HY2"
        let profile = VPNProfile(name: "HY2", protocolType: .hysteria2, rawConfiguration: link, source: .shareLink)

        let json = try SingBoxConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let outbounds = try XCTUnwrap(root["outbounds"] as? [[String: Any]])
        let proxy = outbounds[0]
        XCTAssertEqual(proxy["type"] as? String, "hysteria2")
        XCTAssertEqual(proxy["password"] as? String, "secret")
        XCTAssertEqual(proxy["up_mbps"] as? Int, 100)
        XCTAssertEqual(proxy["down_mbps"] as? Int, 250)
    }

    func testRoutingCompilation() throws {
        let routing = RoutingProfile(
            mode: .vpnOnlyForRules,
            rules: [
                RoutingRule(kind: .domainSuffix, value: ".example.com", action: .vpn),
                RoutingRule(kind: .cidr, value: "10.0.0.0/8", action: .direct),
                RoutingRule(kind: .domain, value: "ads.example", action: .block)
            ]
        )
        let profile = VPNProfile(
            name: "Routing",
            protocolType: .hysteria2,
            rawConfiguration: "hy2://secret@example.com:443",
            routing: routing,
            source: .shareLink
        )

        let json = try SingBoxConfigurationBuilder.build(for: profile)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let route = try XCTUnwrap(root["route"] as? [String: Any])
        XCTAssertEqual(route["final"] as? String, "direct")
        let rules = try XCTUnwrap(route["rules"] as? [[String: Any]])
        XCTAssertEqual(rules.count, 3)
        XCTAssertEqual(rules[0]["outbound"] as? String, "proxy")
        XCTAssertEqual(rules[2]["action"] as? String, "reject")
    }
}
