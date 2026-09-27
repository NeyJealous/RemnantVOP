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
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder != 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }

        guard let encoded = Data(base64Encoded: payload), !encoded.isEmpty else {
            throw ProfileImportError.invalidBase64
        }

        // Amnezia's own importer first tries qUncompress(), but if that fails it
        // treats the Base64-decoded bytes as the configuration itself. This is
        // important for uncompressed vpn:// keys and for compatibility with
        // different generations of Amnezia exports.
        if let directJSON = normalizedJSONString(from: encoded) {
            return directJSON
        }

        if encoded.count > signatureLength {
            let header = encoded.prefix(signatureLength)
            let headerValue = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            let compressed = Data(encoded.dropFirst(signatureLength))

            let expectedSize: Int?
            if headerValue == apiSignature || headerValue == 0 || headerValue > UInt32(maximumOutputSize) {
                expectedSize = nil
            } else {
                expectedSize = Int(headerValue)
            }

            if let uncompressed = try? decompressZlib(compressed, expectedSize: expectedSize),
               let json = normalizedJSONString(from: uncompressed) {
                return json
            }
        }

        // Some third-party exporters store a plain zlib stream without Qt's
        // four-byte qCompress size prefix.
        if let uncompressed = try? decompressZlib(encoded, expectedSize: nil),
           let json = normalizedJSONString(from: uncompressed) {
            return json
        }

        throw ProfileImportError.invalidJSON
    }

    static func suggestedName(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }

        return findFirstString(
            in: object,
            keys: ["description", "server_description", "serverDescription", "name", "configName"]
        )
    }

    private static func normalizedJSONString(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }

        if let nested = object as? String,
           let nestedData = nested.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: nestedData, options: [.fragmentsAllowed])) != nil {
            return nested
        }

        guard object is [String: Any] || object is [Any] else {
            return nil
        }

        return String(data: data, encoding: .utf8)
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
        capacity = min(capacity, maximumOutputSize)

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

            if capacity == maximumOutputSize {
                break
            }
            capacity = min(capacity * 2, maximumOutputSize)
        }

        throw ProfileImportError.invalidCompressedData
    }
}
