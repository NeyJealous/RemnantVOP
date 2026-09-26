import SwiftUI

struct ContentView: View {
    @State private var importText = ""
    @State private var resultText = "Готов к импорту профиля или подписки"

    private let importer = ProfileImporter()

    var body: some View {
        NavigationStack {
            Form {
                Section("Импорт") {
                    TextEditor(text: $importText)
                        .frame(minHeight: 130)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Распознать") {
                        importConfiguration()
                    }
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Результат") {
                    Text(resultText)
                        .font(.footnote)
                        .textSelection(.enabled)
                }

                Section("Phase 0") {
                    Label("AmneziaWG 3.1 — адаптер подготовлен", systemImage: "shield")
                    Label("VLESS — адаптер sing-box подготовлен", systemImage: "point.3.connected.trianglepath.dotted")
                    Label("Hysteria2 — адаптер sing-box подготовлен", systemImage: "bolt.horizontal")
                    Label("Packet Tunnel Extension создан", systemImage: "network")
                }
            }
            .navigationTitle("RemnantVOP")
        }
    }

    private func importConfiguration() {
        do {
            switch try importer.parse(importText) {
            case .profile(let profile):
                resultText = "Профиль: \(profile.name)\nПротокол: \(profile.protocolType.displayName)"
            case .subscription(let url):
                resultText = "Подписка: \(url.absoluteString)"
            }
        } catch {
            resultText = error.localizedDescription
        }
    }
}
