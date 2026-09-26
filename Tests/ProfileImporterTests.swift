import XCTest
@testable import RemnantVOP

final class ProfileImporterTests: XCTestCase {
    private let importer = ProfileImporter()

    func testVLESSLink() throws {
        let result = try importer.parse("vless://00000000-0000-0000-0000-000000000000@example.com:443#Main")
        guard case .profile(let profile) = result else {
            return XCTFail("Expected profile")
        }
        XCTAssertEqual(profile.protocolType, .vless)
        XCTAssertEqual(profile.name, "Main")
    }

    func testHysteria2Alias() throws {
        let result = try importer.parse("hy2://password@example.com:443#HY2")
        guard case .profile(let profile) = result else {
            return XCTFail("Expected profile")
        }
        XCTAssertEqual(profile.protocolType, .hysteria2)
        XCTAssertEqual(profile.name, "HY2")
    }

    func testHTTPSIsSubscription() throws {
        let result = try importer.parse("https://example.com/subscription/token")
        guard case .subscription(let url) = result else {
            return XCTFail("Expected subscription")
        }
        XCTAssertEqual(url.host, "example.com")
    }

    func testAWGConfigText() throws {
        let config = """
        [Interface]
        PrivateKey = redacted

        [Peer]
        PublicKey = redacted
        Endpoint = example.com:443
        """

        let result = try importer.parse(config)
        guard case .profile(let profile) = result else {
            return XCTFail("Expected profile")
        }
        XCTAssertEqual(profile.protocolType, .amneziaWG)
        XCTAssertEqual(profile.source, .configurationText)
    }
}
