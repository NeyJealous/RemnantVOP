import Foundation
import NetworkExtension

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var activeProfile: VPNProfile?
    @Published private(set) var connectedSince: Date?
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    func restoreStatus() async {
        do {
            let managers = try await loadAll()
            if let active = managers.first(where: {
                switch $0.connection.status {
                case .connecting, .connected, .reasserting:
                    return true
                default:
                    return false
                }
            }) {
                manager = active
                observe(active.connection)
                status = active.connection.status
                if status == .connected {
                    connectedSince = active.connection.connectedDate
                }
                if let configuration = (active.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration,
                   let profile = try? TunnelConfigurationStore.profile(from: configuration) {
                    activeProfile = profile
                }
            } else {
                status = .disconnected
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func connect(_ profile: VPNProfile, settings: AppSettings) async throws {
        lastError = nil

        let all = try await loadAll()
        for item in all where item.connection.status != .disconnected && item.connection.status != .invalid {
            item.connection.stopVPNTunnel()
        }

        let providerID = VPNProviderDescriptor.bundleIdentifier(for: profile.protocolType)
        let target = all.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerID
        }) ?? NETunnelProviderManager()

        let provider = NETunnelProviderProtocol()
        provider.providerBundleIdentifier = providerID
        provider.serverAddress = profile.name
        let runtimeOptions = TunnelRuntimeOptions(
            dnsServers: settings.dnsServers,
            diagnosticsLogging: settings.diagnosticsLogging
        )
        provider.providerConfiguration = try TunnelConfigurationStore.providerConfiguration(
            for: profile,
            runtimeOptions: runtimeOptions
        )
        provider.includeAllNetworks = settings.killSwitch
        provider.excludeLocalNetworks = !settings.killSwitch

        target.protocolConfiguration = provider
        target.localizedDescription = "Remnant VPN · \(profile.name)"
        target.isEnabled = true

        if settings.autoConnect {
            target.onDemandRules = [NEOnDemandRuleConnect()]
            target.isOnDemandEnabled = true
        } else {
            target.onDemandRules = nil
            target.isOnDemandEnabled = false
        }

        try await save(target)
        try await load(target)

        manager = target
        activeProfile = profile
        observe(target.connection)

        do {
            try target.connection.startVPNTunnel()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func connectFirstAvailable(
        _ profiles: [VPNProfile],
        settings: AppSettings
    ) async throws {
        guard !profiles.isEmpty else {
            throw VPNFallbackError.noProfiles
        }

        var failures: [String] = []

        for profile in profiles {
            do {
                try await connect(profile, settings: settings)
                try await waitForConnection(timeout: 12)
                return
            } catch {
                failures.append("\(profile.protocolType.displayName): \(error.localizedDescription)")
                manager?.connection.stopVPNTunnel()
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }

        let error = VPNFallbackError.allFailed(failures)
        lastError = error.localizedDescription
        throw error
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    private func waitForConnection(timeout: TimeInterval) async throws {
        let startedAt = Date()
        let grace: TimeInterval = 1.25

        while Date().timeIntervalSince(startedAt) < timeout {
            switch status {
            case .connected:
                return
            case .invalid, .disconnected:
                if Date().timeIntervalSince(startedAt) >= grace {
                    throw VPNFallbackError.connectionRejected
                }
            case .connecting, .reasserting, .disconnecting:
                break
            @unknown default:
                break
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        throw VPNFallbackError.timeout
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
                guard let self, let connection else { return }
                self.status = connection.status
                switch connection.status {
                case .connected:
                    self.connectedSince = connection.connectedDate ?? Date()
                case .disconnected, .invalid:
                    self.connectedSince = nil
                default:
                    break
                }
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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

extension NEVPNStatus {
    var remnantTitle: String {
        switch self {
        case .invalid, .disconnected: return "Защита выключена"
        case .connecting: return "Подключение…"
        case .connected: return "Подключено"
        case .reasserting: return "Восстановление соединения…"
        case .disconnecting: return "Отключение…"
        @unknown default: return "Неизвестное состояние"
        }
    }
}


enum VPNFallbackError: LocalizedError {
    case noProfiles
    case connectionRejected
    case timeout
    case allFailed([String])

    var errorDescription: String? {
        switch self {
        case .noProfiles:
            return "Нет доступных VPN-профилей."
        case .connectionRejected:
            return "VPN-ядро завершило подключение."
        case .timeout:
            return "VPN не успел подключиться."
        case .allFailed(let failures):
            return "Не удалось подключиться автоматически. " + failures.joined(separator: " · ")
        }
    }
}
