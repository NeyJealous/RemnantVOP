import Foundation
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var vpn: VPNManager

    var body: some View {
        ZStack {
            RemnantTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    RemnantCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Текущая сессия")
                                .font(.headline)

                            LabeledContent("Статус", value: vpn.status.remnantTitle)

                            if let profile = vpn.activeProfile {
                                LabeledContent("Сервер", value: profile.name)
                                LabeledContent("Протокол", value: profile.protocolType.displayName)
                            }

                            if let since = vpn.connectedSince {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    LabeledContent("Длительность", value: duration(from: since, to: context.date))
                                }
                            }
                        }
                    }

                    RemnantCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Трафик")
                                .font(.headline)
                            Text("Счётчики отображаются только после того, как конкретное ядро публикует проверяемую телеметрию. Remnant VPN не показывает приблизительные или выдуманные значения.")
                                .font(.footnote)
                                .foregroundStyle(RemnantTheme.muted)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Статистика")
    }

    private func duration(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
