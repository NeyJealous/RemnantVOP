import SwiftUI

struct ServersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var segment = 0
    @State private var searchText = ""
    @State private var showImport = false

    var body: some View {
        ZStack {
            RemnantTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Picker("", selection: $segment) {
                    Text("Серверы").tag(0)
                    Text("Подписки").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if segment == 0 {
                    serverList
                } else {
                    subscriptionList
                }
            }
        }
        .navigationTitle("Серверы")
        .searchable(text: $searchText, prompt: "Найти сервер")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showImport = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showImport) {
            ImportSheet()
        }
    }

    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredGroups.isEmpty {
                    EmptyStateView(
                        title: "Нет серверов",
                        systemImage: "server.rack",
                        message: "Добавьте подписку, ссылку или конфигурацию."
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(filteredGroups) { group in
                        Button {
                            if let preferred = preferredProfile(in: group.profiles) {
                                store.selectProfile(preferred)
                            }
                        } label: {
                            RemnantCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(group.host)
                                                .font(.caption)
                                                .foregroundStyle(RemnantTheme.muted)
                                        }
                                        Spacer()
                                        if group.profiles.contains(where: { $0.id == store.selectedProfile?.id }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(RemnantTheme.accent)
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        ForEach(group.protocols, id: \.rawValue) { kind in
                                            ProtocolBadge(title: kind.shortTitle)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            ForEach(group.profiles) { profile in
                                Button("Выбрать \(profile.protocolType.displayName)") {
                                    store.selectProfile(profile)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var subscriptionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.state.subscriptions) { subscription in
                    RemnantCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subscription.title)
                                        .font(.headline)
                                    Text(subscription.url.host ?? subscription.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(RemnantTheme.muted)
                                }
                                Spacer()
                                if store.isRefreshingSubscriptions {
                                    ProgressView()
                                }
                            }

                            HStack {
                                Label("\(subscription.profileCount)", systemImage: "server.rack")
                                Spacer()
                                if let date = subscription.lastUpdatedAt {
                                    Text(date, style: .relative)
                                        .foregroundStyle(RemnantTheme.muted)
                                } else {
                                    Text("Не обновлялась")
                                        .foregroundStyle(RemnantTheme.muted)
                                }
                            }
                            .font(.caption)

                            if let error = subscription.lastError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(RemnantTheme.danger)
                            }

                            Button("Обновить") {
                                Task {
                                    try? await store.refreshSubscription(subscription.id)
                                }
                            }
                            .buttonStyle(RemnantPrimaryButtonStyle())
                        }
                    }
                }

                if store.state.subscriptions.isEmpty {
                    EmptyStateView(
                        title: "Нет подписок",
                        systemImage: "link",
                        message: "Добавьте HTTPS-ссылку подписки."
                    )
                    .padding(.top, 60)
                }
            }
            .padding()
        }
    }

    private var filteredGroups: [ServerGroup] {
        let groups = Dictionary(grouping: store.state.profiles, by: groupKey)
            .map { key, profiles in
                ServerGroup(
                    id: key,
                    name: profiles.first?.name ?? key,
                    host: endpointHost(profiles.first) ?? key,
                    profiles: profiles
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard !searchText.isEmpty else { return groups }
        return groups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func preferredProfile(in profiles: [VPNProfile]) -> VPNProfile? {
        if let forced = store.state.settings.protocolMode.protocolType {
            return profiles.first(where: { $0.protocolType == forced }) ?? profiles.first
        }

        for kind in store.state.settings.fallbackOrder {
            if let match = profiles.first(where: { $0.protocolType == kind }) {
                return match
            }
        }
        return profiles.first
    }

    private func groupKey(_ profile: VPNProfile) -> String {
        endpointHost(profile)?.lowercased() ?? profile.name.lowercased()
    }

    private func endpointHost(_ profile: VPNProfile?) -> String? {
        guard let profile else { return nil }
        if let components = URLComponents(string: profile.rawConfiguration),
           let host = components.host {
            return host
        }

        for line in profile.rawConfiguration.components(separatedBy: .newlines) {
            let parts = line.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if parts.count == 2, parts[0].lowercased() == "endpoint" {
                let endpoint = parts[1]
                if endpoint.hasPrefix("["),
                   let end = endpoint.firstIndex(of: "]") {
                    return String(endpoint[endpoint.index(after: endpoint.startIndex)..<end])
                }
                return endpoint.split(separator: ":").first.map(String.init)
            }
        }
        return nil
    }
}

private struct ServerGroup: Identifiable {
    let id: String
    let name: String
    let host: String
    let profiles: [VPNProfile]

    var protocols: [TunnelProtocol] {
        Array(Set(profiles.map(\.protocolType))).sorted { $0.rawValue < $1.rawValue }
    }
}
