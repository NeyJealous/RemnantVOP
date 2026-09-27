import Foundation
import Libbox
import NetworkExtension

final class SingBoxRuntime {
    private weak var provider: NEPacketTunnelProvider?
    private var platformInterface: SingBoxPlatformInterface?
    private var commandServer: LibboxCommandServer?
    private var configContent: String?
    private var isStopping = false

    init(provider: NEPacketTunnelProvider) {
        self.provider = provider
    }

    func start(configContent: String) throws {
        guard let provider else {
            throw SingBoxRuntimeError.providerUnavailable
        }

        let directories = try prepareDirectories()

        let setup = LibboxSetupOptions()
        setup.basePath = directories.base.path
        setup.workingPath = directories.working.path
        setup.tempPath = directories.temp.path
        setup.logMaxLines = 3000
        setup.debug = false
        setup.crashReportSource = "NetworkExtension"
        setup.appVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        setup.appMarketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        setup.oomKillerEnabled = true

        var setupError: NSError?
        LibboxSetup(setup, &setupError)
        if let setupError {
            throw setupError
        }

        LibboxPromoteOOMDraft()

        let platform = SingBoxPlatformInterface(provider: provider)
        platform.runtime = self

        var commandError: NSError?
        guard let server = LibboxNewCommandServer(platform, platform, &commandError) else {
            throw commandError ?? SingBoxRuntimeError.commandServerCreationFailed
        }
        if let commandError {
            throw commandError
        }

        do {
            try server.start()
            try server.startOrReloadService(configContent, options: LibboxOverrideOptions())
        } catch {
            server.close()
            throw error
        }

        self.configContent = configContent
        self.platformInterface = platform
        self.commandServer = server
        self.isStopping = false
    }

    func stop() async {
        guard !isStopping else { return }
        isStopping = true

        let server = commandServer

        if let server {
            try? server.closeService()
        }

        platformInterface?.reset()

        if server != nil {
            try? await Task.sleep(nanoseconds: 100_000_000)
            server?.close()
        }

        commandServer = nil
        platformInterface = nil
        configContent = nil
        isStopping = false
    }

    func coreRequestedStop() {
        platformInterface?.reset()
    }

    func reload() throws {
        guard !isStopping,
              let server = commandServer,
              let configContent else {
            throw SingBoxRuntimeError.notRunning
        }
        try server.startOrReloadService(configContent, options: LibboxOverrideOptions())
    }

    private func prepareDirectories() throws -> (base: URL, working: URL, temp: URL) {
        let fileManager = FileManager.default
        let base = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.neyjealous.RemnantVOP"
        ) ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RemnantVOP-SingBox", isDirectory: true)

        let working = base.appendingPathComponent("SingBoxWorking", isDirectory: true)
        let temp = base.appendingPathComponent("SingBoxTemp", isDirectory: true)

        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: working, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: temp, withIntermediateDirectories: true)

        return (base, working, temp)
    }
}

enum SingBoxRuntimeError: LocalizedError {
    case providerUnavailable
    case commandServerCreationFailed
    case notRunning

    var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            return "Packet Tunnel provider уже недоступен."
        case .commandServerCreationFailed:
            return "Не удалось создать sing-box command server."
        case .notRunning:
            return "sing-box не запущен."
        }
    }
}
