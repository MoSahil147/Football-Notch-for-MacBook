// FootballNotch/UI/MatchPickerRow.swift
import SwiftUI

struct MatchPickerRow: View {
    let match: Match
    let onSelect: (Match) -> Void

    var body: some View {
        Button(action: { onSelect(match) }) {
            HStack {
                Text(match.competitionName).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                CrestImageView(team: match.homeTeam)
                Text("\(match.homeScore)-\(match.awayScore)").monospacedDigit()
                CrestImageView(team: match.awayTeam)
                if case .live(let minute) = match.status {
                    Text("\(minute)'").font(.caption2).foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
