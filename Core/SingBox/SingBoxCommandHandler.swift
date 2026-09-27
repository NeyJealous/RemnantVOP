import Foundation
import Libbox

extension SingBoxPlatformInterface: LibboxCommandServerHandlerProtocol {
    func serviceStop() throws {
        runtime?.stop()
    }

    func serviceReload() throws {
        try runtime?.reload()
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        LibboxSystemProxyStatus()
    }

    func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        // System HTTP proxy is intentionally not used by RemnantVOP.
    }

    func triggerNativeCrash() throws {
        throw platformError("Diagnostic crash action is disabled")
    }

    func writeDebugMessage(_ message: String?) {
        #if DEBUG
        if let message {
            print("[sing-box] \(message)")
        }
        #endif
    }

    func connectSSHAgent(_ ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw platformError("SSH agent integration is unavailable")
    }
}
