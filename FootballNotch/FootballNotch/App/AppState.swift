import Foundation

enum NotchDisplayMode: Equatable {
    case hidden
    case compactPill
    case hoverExpanded
    case goalAlert(GoalEvent)
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var mode: NotchDisplayMode
    private let isFollowingMatch: () -> Bool
    private let goalAlertDuration: TimeInterval
    private let collapseDebounce: TimeInterval
    private var wasHoveringBeforeGoalAlert = false
    private var pendingCollapseTask: Task<Void, Never>?

    init(isFollowingMatch: @escaping () -> Bool, goalAlertDuration: TimeInterval = 4.0, collapseDebounce: TimeInterval = 0.18) {
        self.isFollowingMatch = isFollowingMatch
        self.mode = isFollowingMatch() ? .compactPill : .hidden
        self.goalAlertDuration = goalAlertDuration
        self.collapseDebounce = collapseDebounce
    }

    func setFollowingMatch(_ following: Bool) {
        if following {
            if mode == .hidden { mode = .compactPill }
        } else {
            mode = .hidden
        }
    }

    func mouseEntered() {
        // Cancels any pending collapse from a just-prior mouseExited — the
        // panel resizing under the cursor can fire a spurious exit/enter pair
        // mid-animation, which without this would flicker the picker closed
        // right as the user tries to hover it.
        pendingCollapseTask?.cancel()
        pendingCollapseTask = nil
        guard mode == .compactPill || mode == .hidden else { return }
        mode = .hoverExpanded
    }

    func mouseExited() {
        guard mode == .hoverExpanded else { return }
        pendingCollapseTask?.cancel()
        pendingCollapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.collapseDebounce ?? 0.18) * 1_000_000_000))
            guard let self, !Task.isCancelled, self.mode == .hoverExpanded else { return }
            self.mode = self.isFollowingMatch() ? .compactPill : .hidden
        }
    }

    func showGoalAlert(_ event: GoalEvent) {
        mode = .goalAlert(event)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(goalAlertDuration * 1_000_000_000))
            if case .goalAlert(let current) = mode, current == event {
                mode = .compactPill
            }
        }
    }
}
