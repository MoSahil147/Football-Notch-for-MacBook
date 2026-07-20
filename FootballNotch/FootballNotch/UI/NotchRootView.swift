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
                    .id("hidden")
            case .compactPill:
                if let match = polling.followedMatch {
                    CompactPillView(match: match)
                        .id("compactPill")
                }
            case .hoverExpanded:
                HoverExpandedView(
                    liveMatches: polling.liveMatches,
                    followedMatch: polling.followedMatch,
                    followedMatchStats: polling.followedMatchStats,
                    recentGoalEvents: polling.followedMatchGoalEvents,
                    onConfirmMatch: { match, supportedTeamID in
                        polling.follow(match)
                        store.supportedTeamID = supportedTeamID
                    }
                )
                .id("hoverExpanded")
            case .goalAlert(let event):
                if let match = polling.followedMatch {
                    GoalAlertView(event: event, match: match, supportedTeamID: store.supportedTeamID)
                        .id("goalAlert")
                }
            }
        }
        // Content cross-fades alongside NotchPanel's window-frame resize
        // animation (same 0.28s/easeOut) instead of snapping instantly, so
        // the frame and the content it holds animate as one smooth motion
        // rather than the frame gliding while content pops.
        .transition(.opacity)
        .animation(.easeOut(duration: 0.28), value: appState.mode)
    }
}
