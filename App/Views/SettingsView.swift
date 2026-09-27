import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDiagnostics = false
    @State private var showResetConfirmation = false

    var body: some View {
        ZStack {
            RemnantTheme.background.ignoresSafeArea()

            List {
                Section("Подключение") {
                    Toggle("Kill Switch", isOn: $store.state.settings.killSwitch)
                    Toggle("Автовосстановление", isOn: $store.state.settings.autoReconnect)
                    Toggle("Автоподключение", isOn: $store.state.settings.autoConnect)

                    Picker("Протокол", selection: $store.state.settings.protocolMode) {
                        ForEach(ProtocolSelectionMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section("DNS") {
                    Picker("Режим", selection: $store.state.settings.dnsMode) {
                        ForEach(DNSMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if store.state.settings.dnsMode == .custom {
                        TextField(
                            "1.1.1.1, 8.8.8.8",
                            text: Binding(
                                get: { store.state.settings.customDNSServers.joined(separator: ", ") },
                                set: { value in
                                    store.state.settings.customDNSServers = value
                                        .split(separator: ",")
                                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                }
                            )
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                }

                Section("Безопасность") {
                    Toggle("Скрывать секреты конфигурации", isOn: $store.state.settings.hideConfigurationSecrets)
                    Toggle("Подробный диагностический журнал", isOn: $store.state.settings.diagnosticsLogging)
                }

                Section("Система") {
                    NavigationLink("Диагностика") {
                        DiagnosticsView()
                    }

                    Button("Обновить все подписки") {
                        Task { await store.refreshAllSubscriptions() }
                    }

                    Button("Удалить локальные данные", role: .destructive) {
                        showResetConfirmation = true
                    }
                }

                Section("О приложении") {
                    LabeledContent("Версия", value: "1.0.0 RC1")
                    LabeledContent("Ядра", value: "Xray · sing-box · AWG 3.1")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Настройки")
        .confirmationDialog(
            "Удалить профили, подписки и настройки?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить всё", role: .destructive) {
                store.resetAllData()
            }
        }
    }
}
