import SwiftUI

@main
struct RemnantVOPApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var vpnManager = VPNManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(vpnManager)
                .preferredColorScheme(.dark)
                .task {
                    await vpnManager.restoreStatus()
                    if store.state.subscriptions.contains(where: { $0.autoUpdate && $0.isEnabled }) {
                        await store.refreshAllSubscriptions()
                    }
                }
        }
    }
}
