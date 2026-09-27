import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var state: PersistentAppState {
        didSet {
            persist()
        }
    }

    @Published private(set) var isRefreshingSubscriptions = false
    @Published var lastError: String?

    private let storage = SecureStateStore()
    private let subscriptionService = SubscriptionService()
    private let importer = ProfileImporter()

    init() {
        do {
            state = try storage.load() ?? .empty
        } catch {
            state = .empty
            lastError = error.localizedDescription
        }
    }

    var selectedProfile: VPNProfile? {
        guard let id = state.selectedProfileID else {
            return state.profiles.first
        }
        return state.profiles.first(where: { $0.id == id }) ?? state.profiles.first
    }

    var preferredProfile: VPNProfile? {
        if let forced = state.settings.protocolMode.protocolType {
            return matchingProfiles(for: selectedProfile).first(where: { $0.protocolType == forced })
                ?? state.profiles.first(where: { $0.protocolType == forced })
        }

        let candidates = matchingProfiles(for: selectedProfile)
        for kind in state.settings.fallbackOrder {
            if let match = candidates.first(where: { $0.protocolType == kind }) {
                return match
            }
        }
        return selectedProfile ?? state.profiles.first
    }

    func selectProfile(_ profile: VPNProfile) {
        state.selectedProfileID = profile.id
    }

    func removeProfile(_ profile: VPNProfile) {
        state.profiles.removeAll { $0.id == profile.id }
        if state.selectedProfileID == profile.id {
            state.selectedProfileID = state.profiles.first?.id
        }
    }

    func completeOnboarding() {
        state.hasCompletedOnboarding = true
    }

    func importText(_ text: String) async throws {
        switch try importer.parse(text) {
        case .profile(let profile):
            addProfile(profile)
        case .subscription(let url):
            let host = url.host ?? "Подписка"
            let record = SubscriptionRecord(title: host, url: url)
            state.subscriptions.append(record)
            try await refreshSubscription(record.id)
        }
    }

    func addSubscription(url: URL, title: String) async throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = SubscriptionRecord(
            title: cleanTitle.isEmpty ? (url.host ?? "Подписка") : cleanTitle,
            url: url
        )
        state.subscriptions.append(record)
        try await refreshSubscription(record.id)
    }

    func refreshSubscription(_ id: UUID) async throws {
        guard let index = state.subscriptions.firstIndex(where: { $0.id == id }) else {
            return
        }

        isRefreshingSubscriptions = true
        defer { isRefreshingSubscriptions = false }

        let record = state.subscriptions[index]

        do {
            let profiles = try await subscriptionService.fetchProfiles(from: record)
            state.profiles.removeAll { $0.subscriptionID == id }
            state.profiles.append(contentsOf: profiles)
            state.subscriptions[index].lastUpdatedAt = Date()
            state.subscriptions[index].lastError = nil
            state.subscriptions[index].profileCount = profiles.count
            if state.selectedProfileID == nil {
                state.selectedProfileID = profiles.first?.id
            }
        } catch {
            state.subscriptions[index].lastError = error.localizedDescription
            lastError = error.localizedDescription
            throw error
        }
    }

    func refreshAllSubscriptions() async {
        let ids = state.subscriptions.filter { $0.isEnabled }.map { $0.id }
        for id in ids {
            try? await refreshSubscription(id)
        }
    }

    func updateRouting(mode: RoutingProfile.Mode) {
        guard let id = selectedProfile?.id,
              let index = state.profiles.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.profiles[index].routing.mode = mode
    }

    func addRoutingRule(_ rule: RoutingRule) {
        guard let id = selectedProfile?.id,
              let index = state.profiles.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.profiles[index].routing.rules.append(rule)
    }

    func removeRoutingRule(_ ruleID: UUID) {
        guard let id = selectedProfile?.id,
              let index = state.profiles.firstIndex(where: { $0.id == id }) else {
            return
        }
        state.profiles[index].routing.rules.removeAll { $0.id == ruleID }
    }

    func resetAllData() {
        state = .empty
        try? storage.reset()
    }

    private func addProfile(_ profile: VPNProfile) {
        if let existing = state.profiles.first(where: {
            $0.protocolType == profile.protocolType &&
            $0.rawConfiguration == profile.rawConfiguration
        }) {
            state.selectedProfileID = existing.id
            return
        }

        state.profiles.append(profile)
        state.selectedProfileID = profile.id
    }

    private func matchingProfiles(for selected: VPNProfile?) -> [VPNProfile] {
        guard let selected else { return state.profiles }
        let key = groupingKey(selected)
        return state.profiles.filter { groupingKey($0) == key }
    }

    private func groupingKey(_ profile: VPNProfile) -> String {
        if let components = URLComponents(string: profile.rawConfiguration),
           let host = components.host {
            return host.lowercased()
        }
        return profile.name.lowercased()
    }

    private func persist() {
        do {
            try storage.save(state)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
