import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var vpn: VPNManager
    @State private var showImport = false
    @State private var isWorking = false

    private var isConnected: Bool {
        vpn.status == .connected || vpn.status == .connecting || vpn.status == .reasserting
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                connectionControl
                profileCard
                quickTiles
                sessionCard
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(RemnantTheme.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $showImport) {
            ImportSheet()
        }
        .alert("Ошибка подключения", isPresented: Binding(
            get: { vpn.lastError != nil },
            set: { if !$0 { vpn.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { vpn.lastError = nil }
        } message: {
            Text(vpn.lastError ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Remnant VPN")
                    .font(.title2.bold())

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(vpn.status.remnantTitle)
                        .font(.subheadline)
                        .foregroundStyle(RemnantTheme.muted)
                }
            }

            Spacer()

            Menu {
                Button("Обновить подписки") {
                    Task { await store.refreshAllSubscriptions() }
                }
                Button("Диагностика") {}
                if !store.state.profiles.isEmpty {
                    Button("Отключить", role: .destructive) {
                        vpn.disconnect()
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.bold())
                    .frame(width: 42, height: 42)
                    .background(RemnantTheme.card, in: Circle())
            }
        }
    }

    private var connectionControl: some View {
        VStack(spacing: 16) {
            Button {
                Task { await toggleConnection() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.28), lineWidth: 14)
                        .frame(width: 196, height: 196)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [RemnantTheme.cardSecondary, RemnantTheme.background],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 166, height: 166)

                    VStack(spacing: 9) {
                        Image(systemName: isConnected ? "checkmark" : "power")
                            .font(.system(size: 46, weight: .semibold))
                        Text(isConnected ? "Подключено" : "Подключить")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                }
            }
            .disabled(isWorking || store.preferredProfile == nil)

            if let profile = store.preferredProfile {
                Text("\(profile.name) • \(profile.protocolType.displayName)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RemnantTheme.muted)
            } else {
                Button("Добавить VPN или подписку") {
                    showImport = true
                }
                .buttonStyle(RemnantPrimaryButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }

    private var profileCard: some View {
        RemnantCard {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.selectedProfile?.name ?? "Сервер не выбран")
                            .font(.headline)
                        Text(store.selectedProfile?.protocolType.displayName ?? "Добавьте профиль")
                            .font(.subheadline)
                            .foregroundStyle(RemnantTheme.muted)
                    }

                    Spacer()

                    Menu {
                        ForEach(store.state.profiles) { profile in
                            Button {
                                store.selectProfile(profile)
                            } label: {
                                Label(profile.name, systemImage: profile.protocolType.symbolName)
                            }
                        }
                        Divider()
                        Button("Добавить…") {
                            showImport = true
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(RemnantTheme.accent)
                            .frame(width: 40, height: 40)
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack {
                    Text("Протокол")
                        .foregroundStyle(RemnantTheme.muted)
                    Spacer()
                    Menu {
                        ForEach(ProtocolSelectionMode.allCases, id: \.rawValue) { mode in
                            Button(mode.title) {
                                store.state.settings.protocolMode = mode
                            }
                        }
                    } label: {
                        Text(store.state.settings.protocolMode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var quickTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SettingTile(
                title: "Маршрут",
                value: store.selectedProfile?.routing.mode.title ?? "Не выбран",
                icon: "arrow.triangle.branch",
                enabled: true
            )
            SettingTile(
                title: "DNS",
                value: store.state.settings.dnsMode.title,
                icon: "network",
                enabled: true
            )
            SettingTile(
                title: "Kill Switch",
                value: store.state.settings.killSwitch ? "Включён" : "Выключен",
                icon: "lock.shield.fill",
                enabled: store.state.settings.killSwitch
            )
            SettingTile(
                title: "Автовыбор",
                value: store.state.settings.protocolMode == .automatic ? "Включён" : "Ручной",
                icon: "sparkles",
                enabled: store.state.settings.protocolMode == .automatic
            )
        }
    }

    private var sessionCard: some View {
        RemnantCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Текущая сессия")
                    .font(.headline)

                HStack {
                    sessionMetric("Статус", vpn.status.remnantTitle)
                    Spacer()
                    if let since = vpn.connectedSince {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            sessionMetric("Длительность", duration(from: since, to: context.date))
                        }
                    } else {
                        sessionMetric("Длительность", "—")
                    }
                }

                if let profile = vpn.activeProfile {
                    HStack {
                        sessionMetric("Сервер", profile.name)
                        Spacer()
                        sessionMetric("Протокол", profile.protocolType.shortTitle)
                    }
                }
            }
        }
    }

    private func sessionMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(RemnantTheme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var statusColor: Color {
        switch vpn.status {
        case .connected: return RemnantTheme.success
        case .connecting, .reasserting, .disconnecting: return RemnantTheme.warning
        case .invalid, .disconnected: return RemnantTheme.muted
        @unknown default: return RemnantTheme.muted
        }
    }

    private func toggleConnection() async {
        if isConnected {
            vpn.disconnect()
            return
        }

        guard let profile = store.preferredProfile else {
            showImport = true
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await vpn.connect(profile, settings: store.state.settings)
        } catch {
            vpn.lastError = error.localizedDescription
        }
    }

    private func duration(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
    }
}
