import XCTest
@testable import RemnantVOP

final class AWGConfigurationTests: XCTestCase {
    func testStructuredAmneziaJSONProducesAWGQuickConfig() throws {
        let zeroKey = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        let json = """
        {
          "last_config": "{\"hostName\":\"vpn.example.com\",\"port\":443,\"client_ip\":\"10.8.1.2/32\",\"client_priv_key\":\"\(zeroKey)\",\"server_pub_key\":\"\(zeroKey)\",\"allowed_ips\":[\"0.0.0.0/0\",\"::/0\"],\"persistent_keep_alive\":\"5-15\",\"Jc\":\"6\",\"Jmin\":\"10\",\"Jmax\":\"50\",\"S1\":\"12\",\"S2\":\"12\",\"S3\":\"12\",\"S4\":\"12\",\"H1\":\"1\",\"H2\":\"2\",\"H3\":\"3\",\"H4\":\"4\",\"RandomTrailers\":\"1\",\"DisableCookies\":\"1\"}"
        }
        """

        let profile = VPNProfile(
            name: "AWG",
            protocolType: .amneziaWG,
            rawConfiguration: json,
            source: .amneziaVPNLink
        )

        let config = try AmneziaAWGConfigExtractor.configurationText(from: profile)

        XCTAssertTrue(config.contains("Jc = 6"))
        XCTAssertTrue(config.contains("RandomTrailers = 1"))
        XCTAssertTrue(config.contains("DisableCookies = 1"))
        XCTAssertTrue(config.contains("Endpoint = vpn.example.com:443"))
        XCTAssertTrue(config.contains("PersistentKeepalive = 5-15"))
    }
}
