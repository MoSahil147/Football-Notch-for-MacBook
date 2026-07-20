// FootballNotch/UI/HoverExpandedView.swift
import SwiftUI

struct HoverExpandedView: View {
    let liveMatches: [Match]
    let followedMatch: Match?
    let followedMatchStats: MatchStats?
    let recentGoalEvents: [GoalEvent]
    /// Called once the user has picked both a match and which team they're
    /// supporting — that support choice is what GoalAlertView needs to tell
    /// a celebration from a concede.
    let onConfirmMatch: (Match, _ supportedTeamID: String) -> Void

    /// A match the user just tapped, awaiting their "who are you
    /// supporting?" answer before it's actually followed.
    @State private var pendingMatch: Match?

    private var otherMatches: [Match] {
        liveMatches.filter { $0.id != followedMatch?.id }
    }

    /// The expanded panel's top edge is flush with the screen's real top
    /// edge (same as the notch cutout), so content starting right at the top
    /// would render directly under the physical camera housing. Pushing
    /// everything below that band keeps it clear of the dead zone.
    private var topInset: CGFloat {
        guard let screen = NotchGeometry.notchedScreen(), let cutout = NotchGeometry.notchFrame(for: screen) else {
            return 0
        }
        return cutout.height
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0).frame(height: topInset)

            if let pendingMatch {
                SupportTeamPromptView(
                    match: pendingMatch,
                    onPick: { supportedTeamID in
                        UISoundPlayer.playMatchSelected()
                        onConfirmMatch(pendingMatch, supportedTeamID)
                        self.pendingMatch = nil
                    },
                    onBack: { self.pendingMatch = nil }
                )
                .padding(12)
                .frame(maxWidth: .infinity)
            } else {
                // The followed-match summary (pill/stats/goal log) and the
                // "other live matches" list previously lived in the same
                // fixed-height VStack as the panel itself — once the summary
                // content got tall enough (stats + a growing goal log), it
                // silently pushed the match list past the bottom of the
                // panel's fixed 4cm height with no way to reach it. Putting
                // everything inside one ScrollView means it's always
                // reachable by scrolling, regardless of how much summary
                // content there is.
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if let followedMatch {
                            CompactPillView(match: followedMatch)
                            if let followedMatchStats {
                                StatsView(stats: followedMatchStats)
                            }
                            if !recentGoalEvents.isEmpty {
                                GoalLogView(match: followedMatch, events: recentGoalEvents)
                            }
                            Divider()
                            Text("Other live matches").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            Text("Pick a match to follow").font(.caption).bold()
                        }
                        matchList
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        // Fills whatever physical size NotchPanel's expanded frame gives it
        // (sized from the user's cm spec), rather than a fixed point width —
        // NotchPanel.swift, not this view, owns the actual physical dimensions.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.black.opacity(0.95))
        // .continuous (a "squircle") is what gives macOS/iOS UI its
        // characteristic smooth-rounded look, vs. .circular's more
        // mechanical constant-radius corners.
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var matchList: some View {
        if otherMatches.isEmpty {
            Text("No matches available")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(otherMatches) { match in
                    MatchPickerRow(match: match, onSelect: { pendingMatch = $0 })
                }
            }
        }
    }
}

/// Shown after picking a match, before it's actually followed — the answer
/// determines whether a future goal shows a celebration or a "conceded" alert.
private struct SupportTeamPromptView: View {
    let match: Match
    let onPick: (_ supportedTeamID: String) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("Which team are you supporting?").font(.caption).bold()
                Spacer(minLength: 0)
                // Invisible mirror of the back button, same width, so the
                // title is visually centered rather than skewed right by the
                // back button's real width on the left with nothing to
                // balance it on the right.
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .opacity(0)
            }
            HStack(spacing: 8) {
                teamButton(match.homeTeam)
                teamButton(match.awayTeam)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func teamButton(_ team: Team) -> some View {
        Button(action: { onPick(team.id) }) {
            Text(team.shortName)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Simple team-level "who scored" log — ESPN's summary endpoint isn't parsed
/// for individual scorer names yet, so this shows which side scored and the
/// score at that point, not a player name.
private struct GoalLogView: View {
    let match: Match
    let events: [GoalEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                let scorer = event.side == .home ? match.homeTeam.shortName : match.awayTeam.shortName
                Text("⚽️ \(scorer) — \(event.newHomeScore)-\(event.newAwayScore)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
