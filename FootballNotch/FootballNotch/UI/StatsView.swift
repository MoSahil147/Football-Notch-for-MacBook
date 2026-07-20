// FootballNotch/UI/StatsView.swift
import SwiftUI

struct StatsView: View {
    let stats: MatchStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow("Possession", stats.possessionHome, stats.possessionAway, suffix: "%")
            statRow("Shots", stats.shotsHome, stats.shotsAway)
            statRow("On Target", stats.shotsOnTargetHome, stats.shotsOnTargetAway)
            statRow("Fouls", stats.foulsHome, stats.foulsAway)
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func statRow(_ label: String, _ home: Int?, _ away: Int?, suffix: String = "") -> some View {
        if home != nil || away != nil {
            HStack {
                Text("\(home.map(String.init) ?? "-")\(suffix)")
                Spacer()
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text("\(away.map(String.init) ?? "-")\(suffix)")
            }
        }
    }
}
