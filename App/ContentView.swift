import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.state.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .background(RemnantTheme.background.ignoresSafeArea())
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showImport = false

    var body: some View {
        ZStack {
            RemnantTheme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 74, weight: .semibold))
                    .foregroundStyle(RemnantTheme.accent)

                VStack(spacing: 10) {
                    Text("Remnant VPN")
                        .font(.largeTitle.bold())

                    Text("Один клиент. Три протокола.")
                        .font(.headline)
                        .foregroundStyle(RemnantTheme.muted)
                }

                HStack(spacing: 10) {
                    ProtocolBadge(title: "VLESS")
                    ProtocolBadge(title: "Hysteria2")
                    ProtocolBadge(title: "AWG 3.1")
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        store.completeOnboarding()
                        showImport = true
                    } label: {
                        Text("Начать")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RemnantPrimaryButtonStyle())

                    Button("Пропустить") {
                        store.completeOnboarding()
                    }
                    .foregroundStyle(RemnantTheme.muted)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showImport) {
            ImportSheet()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Главная", systemImage: "shield.fill") }

            NavigationStack {
                ServersView()
            }
            .tabItem { Label("Серверы", systemImage: "server.rack") }

            NavigationStack {
                RoutesView()
            }
            .tabItem { Label("Маршруты", systemImage: "arrow.triangle.branch") }

            NavigationStack {
                StatisticsView()
            }
            .tabItem { Label("Статистика", systemImage: "chart.xyaxis.line") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
        .tint(RemnantTheme.accent)
    }
}
