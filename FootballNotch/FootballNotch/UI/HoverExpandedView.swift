// FootballNotch/UI/HoverExpandedView.swift
import SwiftUI

struct HoverExpandedView: View {
    let liveMatches: [Match]
    let followedMatch: Match?
    let followedMatchStats: MatchStats?
    let onSelectMatch: (Match) -> Void

    private var otherMatches: [Match] {
        liveMatches.filter { $0.id != followedMatch?.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let followedMatch {
                CompactPillView(match: followedMatch)
                if let followedMatchStats {
                    StatsView(stats: followedMatchStats)
                }
                Divider()
                Text("Other live matches").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Pick a match to follow").font(.caption).bold()
            }

            if otherMatches.isEmpty {
                Spacer(minLength: 0)
                Text("No matches available")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(otherMatches) { match in
                            MatchPickerRow(match: match, onSelect: onSelectMatch)
                        }
                    }
                }
            }
        }
        .padding(12)
        // Fills whatever physical size NotchPanel's expanded frame gives it
        // (sized from the user's cm spec), rather than a fixed point width —
        // NotchPanel.swift, not this view, owns the actual physical dimensions.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.black.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
