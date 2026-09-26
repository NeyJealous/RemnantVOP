import Compression
import Foundation

enum AmneziaVPNLinkDecoder {
    private static let signatureLength = 4
    private static let apiSignature: UInt32 = 0x000000ff
    private static let maximumOutputSize = 16 * 1024 * 1024

    static func decode(_ link: String) throws -> String {
        guard link.lowercased().hasPrefix("vpn://") else {
            throw ProfileImportError.unsupportedFormat
        }

        var payload = String(link.dropFirst("vpn://".count))
        payload = payload.replacingOccurrences(of: "-", with: "+")
        payload = payload.replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let encoded = Data(base64Encoded: payload),
              encoded.count > signatureLength else {
            throw ProfileImportError.invalidBase64
        }

        let header = encoded.prefix(signatureLength)
        let expectedSize = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let compressed = encoded.dropFirst(signatureLength)

        let outputHint: Int? = (expectedSize == apiSignature || expectedSize == 0)
            ? nil
            : Int(expectedSize)

        let uncompressed = try decompressZlib(Data(compressed), expectedSize: outputHint)

        do {
            _ = try JSONSerialization.jsonObject(with: uncompressed, options: [.fragmentsAllowed])
        } catch {
            throw ProfileImportError.invalidJSON
        }

        guard let json = String(data: uncompressed, encoding: .utf8) else {
            throw ProfileImportError.invalidJSON
        }

        return json
    }

    static func suggestedName(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        return findFirstString(
            in: object,
            keys: ["description", "server_description", "serverDescription", "name", "configName"]
        )
    }

    private static func findFirstString(in value: Any, keys: [String]) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in keys {
                if let string = dictionary[key] as? String,
                   !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return string
                }
            }

            for nested in dictionary.values {
                if let match = findFirstString(in: nested, keys: keys) {
                    return match
                }
            }
        } else if let array = value as? [Any] {
            for nested in array {
                if let match = findFirstString(in: nested, keys: keys) {
                    return match
                }
            }
        }

        return nil
    }

    private static func decompressZlib(_ data: Data, expectedSize: Int?) throws -> Data {
        guard !data.isEmpty else {
            throw ProfileImportError.invalidCompressedData
        }

        var capacity = max(expectedSize ?? max(data.count * 8, 4096), 1024)

        while capacity <= maximumOutputSize {
            var output = Data(count: capacity)

            let decodedCount = output.withUnsafeMutableBytes { destinationBuffer in
                data.withUnsafeBytes { sourceBuffer in
                    guard let destination = destinationBuffer.bindMemory(to: UInt8.self).baseAddress,
                          let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                        return 0
                    }

                    return compression_decode_buffer(
                        destination,
                        capacity,
                        source,
                        data.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }

            if decodedCount > 0 {
                output.count = decodedCount
                return output
            }

            capacity *= 2
        }

        throw ProfileImportError.invalidCompressedData
    }
}
