import SwiftUI

struct ProtocolBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(RemnantTheme.cardSecondary, in: Capsule())
            .foregroundStyle(.white)
    }
}

struct RemnantCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RemnantTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct RemnantPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(RemnantTheme.accent.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SettingTile: View {
    let title: String
    let value: String
    let icon: String
    let enabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(enabled ? RemnantTheme.accent : RemnantTheme.muted)
            Text(title)
                .font(.caption)
                .foregroundStyle(RemnantTheme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(RemnantTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension TunnelProtocol {
    var shortTitle: String {
        switch self {
        case .vless: return "VLESS"
        case .hysteria2: return "Hysteria2"
        case .amneziaWG: return "AWG"
        }
    }

    var symbolName: String {
        switch self {
        case .vless: return "point.3.connected.trianglepath.dotted"
        case .hysteria2: return "bolt.horizontal.fill"
        case .amneziaWG: return "shield.fill"
        }
    }
}

extension RoutingProfile.Mode {
    var title: String {
        switch self {
        case .fullTunnel: return "Весь трафик через VPN"
        case .vpnOnlyForRules: return "Только выбранные через VPN"
        case .bypassRules: return "Исключения напрямую"
        }
    }
}
