import Foundation
import NetworkExtension

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    func installAndConnect(_ profile: VPNProfile) async throws {
        let manager = try await managerForProfile(profile)
        let provider = NETunnelProviderProtocol()
        provider.providerBundleIdentifier = VPNProviderDescriptor.bundleIdentifier(for: profile.protocolType)
        provider.serverAddress = profile.name
        provider.providerConfiguration = try TunnelConfigurationStore.providerConfiguration(for: profile)

        manager.protocolConfiguration = provider
        manager.localizedDescription = "RemnantVOP · \(profile.name)"
        manager.isEnabled = true

        try await save(manager)
        try await load(manager)

        observe(manager.connection)
        try manager.connection.startVPNTunnel()
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    private func managerForProfile(_ profile: VPNProfile) async throws -> NETunnelProviderManager {
        let all = try await loadAll()
        let providerID = VPNProviderDescriptor.bundleIdentifier(for: profile.protocolType)

        if let existing = all.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID
        }) {
            manager = existing
            observe(existing.connection)
            return existing
        }

        let created = NETunnelProviderManager()
        manager = created
        return created
    }

    private func observe(_ connection: NEVPNConnection) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }

        status = connection.status
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: connection,
            queue: .main
        ) { [weak self, weak connection] _ in
            Task { @MainActor in
                self?.status = connection?.status ?? .invalid
            }
        }
    }

    private func loadAll() async throws -> [NETunnelProviderManager] {
        try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: managers ?? [])
                }
            }
        }
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func load(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
