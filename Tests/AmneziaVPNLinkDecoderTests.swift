import XCTest
@testable import RemnantVOP

final class AmneziaVPNLinkDecoderTests: XCTestCase {
    func testQtQCompressVpnKey() throws {
        let link = "vpn://AAAAVXjaDcpRCoAgEAXAu7z_PICH6AIZschWgquSUpHs3fNzYDp8To1C4qvCLh0kib9AEz0HbEek2rZR9jCI7nDm2mYSdrAOd0mGX5IS2fgsDgrVVX8qLx6z"
        let json = try AmneziaVPNLinkDecoder.decode(link)
        XCTAssertTrue(json.contains("containers"))
        XCTAssertTrue(json.contains("vpn.example.com"))
    }

    func testSignedPremiumStyleVpnKey() throws {
        let link = "vpn://AAAA_3icDcpRCoAgEAXAu7z_PICH6AIZschWgquSUpHs3fNzYDp8To1C4qvCLh0kib9AEz0HbEek2rZR9jCI7nDm2mYSdrAOd0mGX5IS2fgsDgrVVX8qLx6z"
        let json = try AmneziaVPNLinkDecoder.decode(link)
        XCTAssertTrue(json.contains("containers"))
    }

    func testUncompressedBase64VpnKey() throws {
        let link = "vpn://eyJjb250YWluZXJzIjpbeyJhbW5lemlhLWF3ZyI6eyJsYXN0X2NvbmZpZyI6IntcImhvc3ROYW1lXCI6XCJ2cG4uZXhhbXBsZS5jb21cIn0ifX1dfQ"
        let json = try AmneziaVPNLinkDecoder.decode(link)
        XCTAssertTrue(json.contains("vpn.example.com"))
    }
}
