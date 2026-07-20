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
    lazy var polling = MatchPollingService(client: ESPNClient(), store: store)
    lazy var appState = AppState(isFollowingMatch: { [store] in store.followedMatchID != nil })
    private var modeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        polling.onGoalEvent = { [weak appState] event in
            appState?.showGoalAlert(event)
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

        // NotchPanel now uses two fixed physical frames (resting/expanded)
        // instead of resizing to fit measured content, so the app layer is
        // responsible for mapping its own display mode onto one of them.
        modeCancellable = appState.$mode.sink { [weak panel] mode in
            switch mode {
            case .hidden, .compactPill:
                panel?.setVisualState(.resting)
            case .hoverExpanded, .goalAlert:
                panel?.setVisualState(.expanded)
            }
        }

        polling.startPolling()
    }
}
