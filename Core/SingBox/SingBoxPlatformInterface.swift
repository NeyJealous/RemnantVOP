import Foundation
import Libbox
import Network
import NetworkExtension

final class SingBoxPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var provider: NEPacketTunnelProvider?
    weak var runtime: SingBoxRuntime?

    private var monitor: NWPathMonitor?
    private var lastNetworkPath: String?
    private var networkSettings: NEPacketTunnelNetworkSettings?

    init(provider: NEPacketTunnelProvider) {
        self.provider = provider
        super.init()
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let provider, let options, let ret0_ else {
            throw platformError("Missing TUN arguments")
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())

            var dnsSettings: NEDNSSettings?
            if options.getDNSMode()?.value != LibboxDNSModeDisabled {
                let iterator = try options.getDNSServerAddress()
                var servers: [String] = []
                while iterator.hasNext() {
                    let server = iterator.next()
                    if !server.isEmpty {
                        servers.append(server)
                    }
                }
                if !servers.isEmpty {
                    let value = NEDNSSettings(servers: servers)
                    settings.dnsSettings = value
                    dnsSettings = value
                }
            }

            let ipv4Iterator = options.getInet4Address()!
            var ipv4Addresses: [String] = []
            var ipv4Masks: [String] = []
            while ipv4Iterator.hasNext() {
                guard let prefix = ipv4Iterator.next() else { continue }
                ipv4Addresses.append(prefix.address())
                ipv4Masks.append(prefix.mask())
            }

            if !ipv4Addresses.isEmpty {
                let ipv4 = NEIPv4Settings(addresses: ipv4Addresses, subnetMasks: ipv4Masks)
                var included: [NEIPv4Route] = []
                let routeIterator = options.getInet4RouteAddress()!
                while routeIterator.hasNext() {
                    guard let prefix = routeIterator.next() else { continue }
                    included.append(
                        NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask())
                    )
                }
                if included.isEmpty {
                    included = [.default()]
                }
                ipv4.includedRoutes = included

                var excluded: [NEIPv4Route] = []
                let excludeIterator = options.getInet4RouteExcludeAddress()!
                while excludeIterator.hasNext() {
                    guard let prefix = excludeIterator.next() else { continue }
                    excluded.append(
                        NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask())
                    )
                }
                ipv4.excludedRoutes = excluded
                settings.ipv4Settings = ipv4

                let hasDefaultRoute = included.contains {
                    $0.destinationAddress == "0.0.0.0" && $0.destinationSubnetMask == "0.0.0.0"
                }
                if !hasDefaultRoute {
                    dnsSettings?.matchDomains = [""]
                    dnsSettings?.matchDomainsNoSearch = true
                }
            }

            let ipv6Iterator = options.getInet6Address()!
            var ipv6Addresses: [String] = []
            var ipv6Prefixes: [NSNumber] = []
            while ipv6Iterator.hasNext() {
                guard let prefix = ipv6Iterator.next() else { continue }
                ipv6Addresses.append(prefix.address())
                ipv6Prefixes.append(NSNumber(value: prefix.prefix()))
            }

            if !ipv6Addresses.isEmpty {
                let ipv6 = NEIPv6Settings(
                    addresses: ipv6Addresses,
                    networkPrefixLengths: ipv6Prefixes
                )
                var included: [NEIPv6Route] = []
                let routeIterator = options.getInet6RouteAddress()!
                while routeIterator.hasNext() {
                    guard let prefix = routeIterator.next() else { continue }
                    included.append(
                        NEIPv6Route(
                            destinationAddress: prefix.address(),
                            networkPrefixLength: NSNumber(value: prefix.prefix())
                        )
                    )
                }
                if included.isEmpty {
                    included = [.default()]
                }
                ipv6.includedRoutes = included

                var excluded: [NEIPv6Route] = []
                let excludeIterator = options.getInet6RouteExcludeAddress()!
                while excludeIterator.hasNext() {
                    guard let prefix = excludeIterator.next() else { continue }
                    excluded.append(
                        NEIPv6Route(
                            destinationAddress: prefix.address(),
                            networkPrefixLength: NSNumber(value: prefix.prefix())
                        )
                    )
                }
                ipv6.excludedRoutes = excluded
                settings.ipv6Settings = ipv6
            }
        }

        var networkError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        provider.setTunnelNetworkSettings(settings) { error in
            networkError = error
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 8) == .timedOut {
            throw platformError("Timed out while applying iOS tunnel network settings")
        }
        if let networkError {
            throw networkError
        }

        networkSettings = settings

        if let fd = provider.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }

        let fd = LibboxGetTunnelFileDescriptor()
        guard fd >= 0 else {
            throw platformError("Unable to locate utun descriptor")
        }
        ret0_.pointee = fd
    }

    func usePlatformAutoDetectControl() -> Bool {
        false
    }

    func autoDetectControl(_: Int32) throws {}

    func useProcFS() -> Bool {
        false
    }

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw platformError("Connection owner lookup is unavailable")
    }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else { return }

        monitor?.cancel()
        lastNetworkPath = nil

        let monitor = NWPathMonitor()
        self.monitor = monitor

        let firstPath = DispatchSemaphore(value: 0)
        var didSignalFirstPath = false

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.updateDefaultInterface(listener, path: path)
            if !didSignalFirstPath {
                didSignalFirstPath = true
                firstPath.signal()
            }
        }

        monitor.start(queue: DispatchQueue(label: "RemnantVOP.SingBox.Network"))

        if firstPath.wait(timeout: .now() + 8) == .timedOut {
            monitor.cancel()
            self.monitor = nil
            throw platformError("Timed out while waiting for the physical network interface")
        }
    }

    private func updateDefaultInterface(
        _ listener: LibboxInterfaceUpdateListenerProtocol,
        path: NWPath
    ) {
        let description = describeNetworkPath(path)
        listener.updateNetworkPath(description)

        if description == lastNetworkPath {
            return
        }
        lastNetworkPath = description

        guard path.status != .unsatisfied,
              let interface = path.availableInterfaces.first else {
            listener.updateDefaultInterface(
                "",
                interfaceIndex: -1,
                isExpensive: false,
                isConstrained: false
            )
            return
        }

        listener.updateDefaultInterface(
            interface.name,
            interfaceIndex: Int32(interface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    private func describeNetworkPath(_ path: NWPath) -> String {
        var components: [String] = []

        switch path.status {
        case .satisfied:
            components.append("satisfied")
        case .unsatisfied:
            components.append("unsatisfied")
        case .requiresConnection:
            components.append("requiresConnection")
        @unknown default:
            components.append("unknown")
        }

        if !path.availableInterfaces.isEmpty {
            components.append(
                "interfaces=" + path.availableInterfaces
                    .map { "\($0.name)#\($0.index)/\($0.type)" }
                    .joined(separator: ",")
            )
        }
        if path.supportsIPv4 { components.append("ipv4") }
        if path.supportsIPv6 { components.append("ipv6") }
        if path.supportsDNS { components.append("dns") }
        if path.isExpensive { components.append("expensive") }
        if path.isConstrained { components.append("constrained") }

        return components.joined(separator: " ")
    }

    func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
        monitor?.cancel()
        monitor = nil
        lastNetworkPath = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let monitor else {
            throw platformError("NWPathMonitor has not been started")
        }

        let path = monitor.currentPath
        if path.status == .unsatisfied {
            return SingBoxNetworkInterfaceIterator([])
        }

        let interfaces = path.availableInterfaces.map { value -> LibboxNetworkInterface in
            let item = LibboxNetworkInterface()
            item.name = value.name
            item.index = Int32(value.index)
            item.metered = path.isExpensive
            switch value.type {
            case .wifi:
                item.type = LibboxInterfaceTypeWIFI
            case .cellular:
                item.type = LibboxInterfaceTypeCellular
            case .wiredEthernet:
                item.type = LibboxInterfaceTypeEthernet
            default:
                item.type = LibboxInterfaceTypeOther
            }
            return item
        }
        return SingBoxNetworkInterfaceIterator(interfaces)
    }

    func underNetworkExtension() -> Bool {
        true
    }

    func includeAllNetworks() -> Bool {
        provider?.protocolConfiguration.includeAllNetworks ?? false
    }

    func readWIFIState() -> LibboxWIFIState? {
        nil
    }

    func clearDNSCache() {
        guard let provider, let networkSettings else { return }

        provider.reasserting = true
        let semaphore = DispatchSemaphore(value: 0)
        provider.setTunnelNetworkSettings(nil) { _ in
            provider.setTunnelNetworkSettings(networkSettings) { _ in
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .now() + 4)
        provider.reasserting = false
    }

    func send(_ notification: LibboxNotification?) throws {}

    func cancelNotification(_ identifier: String?, typeID: Int32) throws {}

    func startNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}

    func closeNeighborMonitor(_ listener: LibboxNeighborUpdateListenerProtocol?) throws {}

    func registerMyInterface(_ name: String?) {}

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? {
        nil
    }

    func usePlatformShell() -> Bool {
        false
    }

    func checkPlatformShell() throws {
        throw platformError("Platform shell is unavailable")
    }

    func openShellSession(
        _ user: LibboxPlatformUser?,
        command: String?,
        environ: (any LibboxStringIteratorProtocol)?,
        term: String?,
        rows: Int32,
        cols: Int32
    ) throws -> any LibboxShellSessionProtocol {
        throw platformError("Platform shell is unavailable")
    }

    func lookupUser(_ username: String?) throws -> LibboxPlatformUser {
        throw platformError("User lookup is unavailable")
    }

    func lookupSFTPServer(_ error: NSErrorPointer) -> String {
        error?.pointee = platformError("SFTP lookup is unavailable")
        return ""
    }

    func readSystemSSHHostKey(_ error: NSErrorPointer) -> String {
        error?.pointee = platformError("Host key lookup is unavailable")
        return ""
    }

    func tailscaleHostname() -> String {
        ""
    }

    func usePlatformBridge() -> Bool {
        false
    }

    func createBridge(_ options: LibboxBridgeOptions?) throws -> any LibboxBridgeSessionProtocol {
        throw platformError("Platform bridge is unavailable")
    }

    func reset() {
        monitor?.cancel()
        monitor = nil
        lastNetworkPath = nil
        networkSettings = nil
    }

    func platformError(_ message: String) -> NSError {
        NSError(
            domain: "RemnantVOP.SingBoxPlatform",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private final class SingBoxNetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    private var buffered: LibboxNetworkInterface?

    init(_ values: [LibboxNetworkInterface]) {
        iterator = values.makeIterator()
    }

    func hasNext() -> Bool {
        if buffered == nil {
            buffered = iterator.next()
        }
        return buffered != nil
    }

    func next() -> LibboxNetworkInterface? {
        if let buffered {
            self.buffered = nil
            return buffered
        }
        return iterator.next()
    }
}
