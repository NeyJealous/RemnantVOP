import Darwin
import Foundation
import Network
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var pathMonitor: NWPathMonitor?
    private let pathQueue = DispatchQueue(label: "RemnantVOP.Mihomo.Network")
    private var lastPathSignature: String?
    private var coreStarted = false

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            completionHandler(MihomoPacketTunnelError.invalidProtocolConfiguration)
            return
        }

        let profile: VPNProfile
        let runtimeOptions = TunnelConfigurationStore.runtimeOptions(
            from: tunnelProtocol.providerConfiguration
        )

        do {
            profile = try TunnelConfigurationStore.profile(
                from: tunnelProtocol.providerConfiguration
            )
            guard profile.protocolType == .hysteria2 else {
                throw MihomoPacketTunnelError.wrongProtocol
            }
        } catch {
            completionHandler(error)
            return
        }

        let configuration: String
        do {
            configuration = try MihomoConfigurationBuilder.build(
                for: profile,
                runtimeOptions: runtimeOptions
            )
        } catch {
            completionHandler(error)
            return
        }

        setTunnelNetworkSettings(makeNetworkSettings()) { [weak self] error in
            guard let self else {
                completionHandler(MihomoPacketTunnelError.providerUnavailable)
                return
            }
            if let error {
                completionHandler(error)
                return
            }

            do {
                guard let fd = self.packetFlowFileDescriptor() else {
                    throw MihomoPacketTunnelError.tunnelDescriptorUnavailable
                }

                let working = try self.prepareWorkingDirectory()
                MihomoBridge.setHomeDirectory(working.path)
                try MihomoBridge.setTunnelFileDescriptor(fd)
                try MihomoBridge.start(configuration: configuration)

                self.coreStarted = true
                self.startPathMonitor()
                completionHandler(nil)
            } catch {
                self.stopPathMonitor()
                MihomoBridge.stop()
                self.coreStarted = false
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        stopPathMonitor()
        MihomoBridge.stop()
        coreStarted = false
        completionHandler()
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
        guard coreStarted else { return }
        MihomoBridge.notifyDefaultInterfaceChanged()
    }

    private func makeNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500

        let ipv4 = NEIPv4Settings(
            addresses: ["198.18.0.1"],
            subnetMasks: ["255.255.0.0"]
        )
        ipv4.includedRoutes = [.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(
            addresses: ["fd00:7f::1"],
            networkPrefixLengths: [64]
        )
        ipv6.includedRoutes = [.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: ["198.18.0.2", "fd00:7f::2"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        return settings
    }

    private func prepareWorkingDirectory() throws -> URL {
        let manager = FileManager.default
        let base = manager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.neyjealous.RemnantVOP"
        ) ?? manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RemnantVOP-Mihomo", isDirectory: true)

        let working = base.appendingPathComponent("MihomoWorking", isDirectory: true)
        try manager.createDirectory(at: working, withIntermediateDirectories: true)
        return working
    }

    private func packetFlowFileDescriptor() -> Int32? {
        let candidates = [
            "socket.fileDescriptor",
            "_socket.fileDescriptor",
            "socket._fileDescriptor",
            "_socket._fileDescriptor"
        ]

        for keyPath in candidates {
            let raw = packetFlow.value(forKeyPath: keyPath)
            if let number = raw as? NSNumber, number.int32Value > 0 {
                return number.int32Value
            }
            if let fd = raw as? Int32, fd > 0 {
                return fd
            }
        }

        return findUtunFileDescriptor()
    }

    private func findUtunFileDescriptor() -> Int32? {
        let afSystem: UInt8 = 32
        let afSysControl: UInt16 = 2
        let limit = Int32(getdtablesize())

        for fd in 0..<limit {
            var storage = sockaddr_storage()
            var length = socklen_t(MemoryLayout<sockaddr_storage>.size)

            let result = withUnsafeMutablePointer(to: &storage) { pointer -> Int32 in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getpeername(fd, $0, &length)
                }
            }
            guard result == 0 else { continue }

            let family: UInt8 = withUnsafeBytes(of: storage) { $0[1] }
            guard family == afSystem else { continue }

            let systemAddress: UInt16 = withUnsafeBytes(of: storage) {
                $0.load(fromByteOffset: 2, as: UInt16.self)
            }
            if systemAddress == afSysControl {
                return fd
            }
        }

        return nil
    }

    private func startPathMonitor() {
        stopPathMonitor()

        let monitor = NWPathMonitor()
        pathMonitor = monitor
        lastPathSignature = nil

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self, self.coreStarted else { return }

            let signature = self.pathSignature(path)
            defer { self.lastPathSignature = signature }

            guard path.status == .satisfied else { return }

            MihomoBridge.notifyDefaultInterfaceChanged()

            if let previous = self.lastPathSignature, previous != signature {
                _ = MihomoBridge.closeAllConnections()
            }
        }
        monitor.start(queue: pathQueue)
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
        lastPathSignature = nil
    }

    private func pathSignature(_ path: NWPath) -> String {
        let interfaces = path.availableInterfaces
            .map { "\($0.name)#\($0.index)-\($0.type)" }
            .sorted()
            .joined(separator: ",")
        return "\(path.status)-\(path.isExpensive)-\(path.isConstrained)-\(interfaces)"
    }
}

enum MihomoPacketTunnelError: LocalizedError {
    case invalidProtocolConfiguration
    case wrongProtocol
    case providerUnavailable
    case tunnelDescriptorUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidProtocolConfiguration:
            return "Некорректная конфигурация Mihomo Packet Tunnel."
        case .wrongProtocol:
            return "Mihomo Packet Tunnel получил профиль другого протокола."
        case .providerUnavailable:
            return "Mihomo Packet Tunnel уже недоступен."
        case .tunnelDescriptorUnavailable:
            return "Не удалось получить файловый дескриптор iOS utun."
        }
    }
}
