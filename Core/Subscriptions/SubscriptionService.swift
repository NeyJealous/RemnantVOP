import Foundation

struct SubscriptionService {
    private let importer = ProfileImporter()
    private let maximumBytes = 8 * 1024 * 1024

    func fetchProfiles(from subscription: SubscriptionRecord) async throws -> [VPNProfile] {
        var request = URLRequest(url: subscription.url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("RemnantVPN/1.0 iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("text/plain, application/json, */*", forHTTPHeaderField: "Accept")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)
        guard data.count <= maximumBytes else {
            throw SubscriptionServiceError.responseTooLarge
        }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SubscriptionServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        guard let raw = String(data: data, encoding: .utf8) else {
            throw SubscriptionServiceError.invalidEncoding
        }

        let text = decodedSubscriptionText(raw)
        var profiles: [VPNProfile] = []

        for candidate in splitCandidates(text) {
            do {
                let result = try importer.parse(candidate)
                if case .profile(var profile) = result {
                    profile.source = .subscription
                    profile.subscriptionID = subscription.id
                    profiles.append(profile)
                }
            } catch {
                continue
            }
        }

        if profiles.isEmpty {
            profiles = parseSingBoxJSON(text, subscriptionID: subscription.id)
        }

        guard !profiles.isEmpty else {
            throw SubscriptionServiceError.noSupportedProfiles
        }

        var seen = Set<String>()
        return profiles.filter {
            let key = "\($0.protocolType.rawValue)|\($0.rawConfiguration)"
            return seen.insert(key).inserted
        }
    }

    private func decodedSubscriptionText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") || trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return trimmed
        }

        var base64 = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8),
              decoded.contains("://") else {
            return trimmed
        }
        return decoded
    }

    private func splitCandidates(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    private func parseSingBoxJSON(_ text: String, subscriptionID: UUID) -> [VPNProfile] {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outbounds = root["outbounds"] as? [[String: Any]] else {
            return []
        }

        return outbounds.compactMap { outbound in
            guard let type = outbound["type"] as? String else { return nil }
            let name = (outbound["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? type

            switch type.lowercased() {
            case "hysteria2":
                guard JSONSerialization.isValidJSONObject(["outbounds": [outbound]]),
                      let data = try? JSONSerialization.data(withJSONObject: ["outbounds": [outbound]]),
                      let json = String(data: data, encoding: .utf8) else {
                    return nil
                }
                return VPNProfile(
                    name: name,
                    protocolType: .hysteria2,
                    rawConfiguration: json,
                    source: .subscription,
                    subscriptionID: subscriptionID
                )
            default:
                return nil
            }
        }
    }
}

enum SubscriptionServiceError: LocalizedError {
    case responseTooLarge
    case httpStatus(Int)
    case invalidEncoding
    case noSupportedProfiles

    var errorDescription: String? {
        switch self {
        case .responseTooLarge:
            return "Подписка превышает допустимый размер."
        case .httpStatus(let code):
            return "Сервер подписки вернул HTTP \(code)."
        case .invalidEncoding:
            return "Не удалось прочитать текст подписки."
        case .noSupportedProfiles:
            return "В подписке не найдено VLESS, Hysteria2 или AmneziaWG."
        }
    }
}
