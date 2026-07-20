import SwiftUI
import AppKit
import Combine

@main
struct FootballNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchPanel: NotchPanel?
    let store = FollowedMatchStore()
    lazy var polling = MatchPollingService(client: Self.makeClient(), store: store)
    lazy var appState = AppState(isFollowingMatch: { [store] in store.followedMatchID != nil })
    private var modeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Demo mode should always start from a blank slate — real usage
        // deliberately persists the followed match across launches (that's
        // the whole point of FollowedMatchStore), but a leftover
        // followedMatchID from a previous demo run would skip straight past
        // the idle → pick-a-match flow this mode exists to let you test.
        // Must happen before `appState` (lazy) is first touched below, since
        // its initial mode reads store.followedMatchID at construction time.
        if Self.isDemoMode {
            store.clear()
        }

        polling.onGoalEvent = { [weak appState] event in
            appState?.showGoalAlert(event)
        }
        polling.onMatchFinished = { outcome in
            GoalSoundPlayer.play(outcome: outcome)
        }

        NotificationCenter.default.addObserver(forName: NotchPanel.mouseEnteredNotification, object: nil, queue: .main) { [weak appState] _ in
            appState?.mouseEntered()
        }
        NotificationCenter.default.addObserver(forName: NotchPanel.mouseExitedNotification, object: nil, queue: .main) { [weak appState] _ in
            appState?.mouseExited()
        }

        let rootView = NotchRootView(appState: appState, polling: polling, store: store)
        let panel = NotchPanel.makeAndShow(content: rootView)
        notchPanel = panel

        // NotchPanel now uses fixed physical frames (idle/compact/expanded)
        // instead of resizing to fit measured content, so the app layer is
        // responsible for mapping its own display mode onto one of them.
        modeCancellable = appState.$mode.sink { [weak panel] mode in
            switch mode {
            case .hidden:
                panel?.setVisualState(.idle)
            case .compactPill:
                panel?.setVisualState(.compact)
            case .hoverExpanded, .goalAlert:
                panel?.setVisualState(.expanded)
            }
        }

        polling.startPolling()
    }

    /// Debug-only escape hatch to see the full idle → pick-a-match →
    /// compact-pill → hover-stats → goal-alert flow without waiting for a
    /// real live match: set FN_DEMO_MODE=1 in the Xcode scheme's Run >
    /// Arguments > Environment Variables. `DemoESPNClient` doesn't exist in
    /// Release builds at all (it's `#if DEBUG`-only), so this can never
    /// activate outside a debug build even if the env var were somehow set.
    private static func makeClient() -> ESPNClientProtocol {
        #if DEBUG
        if isDemoMode {
            return DemoESPNClient()
        }
        #endif
        return ESPNClient()
    }

    private static var isDemoMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FN_DEMO_MODE"] == "1"
        #else
        false
        #endif
    }
}
