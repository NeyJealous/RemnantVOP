import Foundation

struct SubscriptionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var url: URL
    var isEnabled: Bool
    var autoUpdate: Bool
    var lastUpdatedAt: Date?
    var lastError: String?
    var profileCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        isEnabled: Bool = true,
        autoUpdate: Bool = true,
        lastUpdatedAt: Date? = nil,
        lastError: String? = nil,
        profileCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isEnabled = isEnabled
        self.autoUpdate = autoUpdate
        self.lastUpdatedAt = lastUpdatedAt
        self.lastError = lastError
        self.profileCount = profileCount
    }
}

struct PersistentAppState: Codable, Equatable, Sendable {
    var profiles: [VPNProfile]
    var subscriptions: [SubscriptionRecord]
    var selectedProfileID: UUID?
    var settings: AppSettings
    var hasCompletedOnboarding: Bool

    static let empty = PersistentAppState(
        profiles: [],
        subscriptions: [],
        selectedProfileID: nil,
        settings: .standard,
        hasCompletedOnboarding: false
    )
}
