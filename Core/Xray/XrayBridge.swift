import Foundation
import LibXray

enum XrayBridge {
    static func invoke(method: String, payload: [String: Any] = [:]) throws -> [String: Any] {
        let request: [String: Any] = [
            "apiVersion": 3,
            "method": method,
            "payload": payload
        ]

        guard JSONSerialization.isValidJSONObject(request) else {
            throw XrayBridgeError.invalidRequest
        }

        let requestData = try JSONSerialization.data(withJSONObject: request)
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            throw XrayBridgeError.invalidRequest
        }

        var bytes = requestString.utf8CString
        guard let pointer = bytes.withUnsafeMutableBufferPointer({ buffer in
            CGoInvoke(buffer.baseAddress)
        }) else {
            throw XrayBridgeError.emptyResponse
        }
        defer { CGoFree(pointer) }

        let responseString = String(cString: pointer)
        guard let responseData = responseString.data(using: .utf8),
              let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        else {
            throw XrayBridgeError.invalidResponse
        }

        guard response["success"] as? Bool == true else {
            let message = response["error"] as? String ?? "Unknown libXray error"
            throw XrayBridgeError.core(message)
        }

        return response["data"] as? [String: Any] ?? [:]
    }

    static func stop() {
        _ = try? invoke(method: "stopXray")
    }
}

enum XrayBridgeError: LocalizedError {
    case invalidRequest
    case emptyResponse
    case invalidResponse
    case core(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Не удалось сформировать запрос к libXray."
        case .emptyResponse:
            return "libXray не вернул ответ."
        case .invalidResponse:
            return "libXray вернул некорректный ответ."
        case .core(let message):
            return message
        }
    }
}
