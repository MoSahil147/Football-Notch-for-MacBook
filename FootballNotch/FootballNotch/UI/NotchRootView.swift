// FootballNotch/UI/NotchRootView.swift
import SwiftUI

struct NotchRootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var polling: MatchPollingService
    let store: FollowedMatchStore

    var body: some View {
        Group {
            switch appState.mode {
            case .hidden:
                IdleIndicatorView()
            case .compactPill:
                if let match = polling.followedMatch {
                    CompactPillView(match: match)
                }
            case .hoverExpanded:
                HoverExpandedView(
                    liveMatches: polling.liveMatches,
                    followedMatch: polling.followedMatch,
                    followedMatchStats: polling.followedMatchStats,
                    onSelectMatch: { match in
                        polling.follow(matchID: match.id)
                        store.followedMatchID = match.id
                    }
                )
            case .goalAlert(let event):
                if let match = polling.followedMatch {
                    GoalAlertView(event: event, match: match, supportedTeamID: store.supportedTeamID)
                }
            }
        }
    }
}
