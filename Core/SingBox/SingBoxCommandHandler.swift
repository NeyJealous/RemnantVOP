import Foundation
import Libbox

extension SingBoxPlatformInterface: LibboxCommandServerHandlerProtocol {
    func serviceStop() throws {
        // Do not call SingBoxRuntime.stop() from this callback. closeService()
        // may invoke the command handler, and recursively closing the command
        // server leaves the extension in a state where the next start fails.
        runtime?.coreRequestedStop()
    }

    func serviceReload() throws {
        try runtime?.reload()
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        LibboxSystemProxyStatus()
    }

    func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        // System HTTP proxy is intentionally not used by Remnant VPN.
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
