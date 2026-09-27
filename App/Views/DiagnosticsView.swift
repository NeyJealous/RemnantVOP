import Foundation\nimport SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var vpn: VPNManager
    @State private var isRunning = false
    @State private var internetResult: String = "Не проверено"
    @State private var profileResult: String = "Не проверено"

    var body: some View {
        List {
            Section("VPN") {
                LabeledContent("Network Extension", value: vpn.status.remnantTitle)
                LabeledContent("Профиль", value: profileResult)
            }

            Section("Сеть") {
                LabeledContent("Интернет", value: internetResult)
            }

            Section {
                Button {
                    Task { await runDiagnostics() }
                } label: {
                    if isRunning {
                        HStack {
                            ProgressView()
                            Text("Проверка…")
                        }
                    } else {
                        Label("Запустить полную проверку", systemImage: "stethoscope")
                    }
                }
                .disabled(isRunning)
            }
        }
        .navigationTitle("Диагностика")
        .task {
            validateProfile()
        }
    }

    private func validateProfile() {
        guard let profile = store.preferredProfile else {
            profileResult = "Нет профиля"
            return
        }

        do {
            _ = try ProfileImporter().parse(profile.rawConfiguration)
            profileResult = "Конфигурация распознана"
        } catch {
            if profile.source == .subscription {
                profileResult = "Подписка загружена"
            } else {
                profileResult = error.localizedDescription
            }
        }
    }

    private func runDiagnostics() async {
        isRunning = true
        defer { isRunning = false }

        guard let url = URL(string: "https://cp.cloudflare.com/generate_204") else {
            internetResult = "Ошибка URL"
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                internetResult = "Доступен"
            } else {
                internetResult = "Нет ответа"
            }
        } catch {
            internetResult = error.localizedDescription
        }

        validateProfile()
    }
}
