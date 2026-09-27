import SwiftUI

struct RoutesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAddRule = false

    var body: some View {
        ZStack {
            RemnantTheme.background.ignoresSafeArea()

            List {
                Section("Режим") {
                    ForEach([RoutingProfile.Mode.fullTunnel, .vpnOnlyForRules, .bypassRules], id: \.rawValue) { mode in
                        Button {
                            store.updateRouting(mode: mode)
                        } label: {
                            HStack {
                                Text(mode.title)
                                Spacer()
                                if store.selectedProfile?.routing.mode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(RemnantTheme.accent)
                                }
                            }
                        }
                        .foregroundStyle(.white)
                    }
                }

                Section("Пользовательские правила") {
                    ForEach(store.selectedProfile?.routing.rules ?? []) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rule.value)
                                Text("\(rule.kind.title) • \(rule.action.title)")
                                    .font(.caption)
                                    .foregroundStyle(RemnantTheme.muted)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                store.removeRoutingRule(rule.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    Button {
                        showAddRule = true
                    } label: {
                        Label("Добавить правило", systemImage: "plus")
                    }
                }

                Section("Приоритет") {
                    Text("Пользовательские правила обрабатываются до основного маршрута. Xray и Hysteria2 поддерживают доменные правила; для AWG доменные назначения зависят от IP-маршрутов.")
                        .font(.footnote)
                        .foregroundStyle(RemnantTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Маршруты")
        .sheet(isPresented: $showAddRule) {
            AddRouteRuleView()
        }
    }
}

private struct AddRouteRuleView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RoutingRule.Kind = .domainSuffix
    @State private var action: RoutingRule.Action = .vpn
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Тип", selection: $kind) {
                    ForEach(RoutingRule.Kind.allCases, id: \.rawValue) { item in
                        Text(item.title).tag(item)
                    }
                }

                TextField("example.com или 10.0.0.0/8", text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Действие", selection: $action) {
                    ForEach(RoutingRule.Action.allCases, id: \.rawValue) { item in
                        Text(item.title).tag(item)
                    }
                }
            }
            .navigationTitle("Новое правило")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        store.addRoutingRule(RoutingRule(kind: kind, value: clean, action: action))
                        dismiss()
                    }
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

extension RoutingRule.Kind: CaseIterable {
    static var allCases: [RoutingRule.Kind] {
        [.domain, .domainSuffix, .cidr, .ip]
    }

    var title: String {
        switch self {
        case .domain: return "Домен"
        case .domainSuffix: return "Суффикс домена"
        case .cidr: return "IP / CIDR"
        case .ip: return "IP"
        }
    }
}

extension RoutingRule.Action: CaseIterable {
    static var allCases: [RoutingRule.Action] {
        [.vpn, .direct, .block]
    }

    var title: String {
        switch self {
        case .vpn: return "Через VPN"
        case .direct: return "Напрямую"
        case .block: return "Блокировать"
        }
    }
}
