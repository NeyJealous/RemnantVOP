import Foundation
@preconcurrency import Libmihomo

enum MihomoBridge {
    static func setHomeDirectory(_ path: String) {
        LibmihomoSetHomeDir(path)
    }

    static func setTunnelFileDescriptor(_ fd: Int32) throws {
        var error: NSError?
        let ok = LibmihomoSetTunFd(Int(fd), &error)
        guard ok else {
            throw error ?? MihomoBridgeError.operationFailed("SetTunFd")
        }
    }

    static func start(configuration: String) throws {
        var error: NSError?
        let ok = LibmihomoStartRemnant(configuration, &error)
        guard ok else {
            throw error ?? MihomoBridgeError.operationFailed("StartRemnant")
        }
    }

    static func reload(configuration: String) throws {
        var error: NSError?
        let ok = LibmihomoReloadRemnant(configuration, &error)
        guard ok else {
            throw error ?? MihomoBridgeError.operationFailed("ReloadRemnant")
        }
    }

    static func stop() {
        LibmihomoStop()
    }

    static func notifyDefaultInterfaceChanged() {
        LibmihomoNotifyDefaultInterfaceChanged()
    }

    @discardableResult
    static func closeAllConnections() -> Int {
        Int(LibmihomoCloseAllConnections())
    }
}

enum MihomoBridgeError: LocalizedError {
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "Mihomo: операция \(operation) завершилась ошибкой."
        }
    }
}
