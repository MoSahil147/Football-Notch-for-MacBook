import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    static let mouseEnteredNotification = Notification.Name("NotchPanel.mouseEntered")
    static let mouseExitedNotification = Notification.Name("NotchPanel.mouseExited")

    enum VisualState {
        case idle
        case compact
        case expanded
    }

    // Physical layout matched to a real-device spec rather than derived from
    // measured content size: the pill's top edge sits flush with the
    // screen's real top edge (the same row the camera notch occupies), and
    // expands downward + sideways to an exact physical block on hover. Fixed
    // target frames (vs. the earlier content-driven measure->resize->
    // re-measure loop) is also what fixed the flicker and
    // hover-breaking-after-first-cycle bugs.
    private static let expandedHeightCM: CGFloat = 4
    private static let expandedSideMarginCM: CGFloat = 2
    // Idle (nothing tracked): just enough overflow past the notch's
    // dead-pixel cutout for the emoji to land on visible pixels — kept
    // small and tight to the camera, matching the original look.
    private static let idleSideMarginPoints: CGFloat = 20
    // Compact (a match is being tracked): enough room for "HOME vs AWAY" on
    // the left and a score on the right, split around the dead zone. Left is
    // wider than right since team-name text needs more room than a score.
    private static let compactLeftMarginPoints: CGFloat = 90
    private static let compactRightMarginPoints: CGFloat = 55

    private var idleFrame: CGRect = .zero
    private var compactFrame: CGRect = .zero
    private var expandedFrame: CGRect = .zero
    private var currentState: VisualState = .idle

    // NSTrackingArea's mouseEntered/mouseExited delivery turned out unreliable
    // on a borderless, non-activating, .screenSaver-level panel like this one
    // — it would stop firing after the first hover/collapse cycle even after
    // being reinstalled post-resize. Polling the global cursor position
    // against the panel's own frame sidesteps AppKit's hover-tracking
    // machinery entirely and is what real notch-overlay apps use for exactly
    // this reason.
    private var hoverPollTimer: Timer?
    private var isMouseInsideNotch = false

    // Without this, hovering works (tracking areas don't need focus) but
    // clicks on match rows/buttons do nothing: a non-activating accessory-app
    // panel like this one never naturally becomes key on its own, and
    // ClickThroughHostingView (below) is what stops that first click from
    // being swallowed just to focus the window instead of reaching the view.
    override var canBecomeKey: Bool { true }

    static func makeAndShow<Content: View>(content: Content) -> NotchPanel {
        let screen = NotchGeometry.notchedScreen() ?? NSScreen.main
        let cutout = screen.flatMap(NotchGeometry.notchFrame(for:)) ?? CGRect(x: 0, y: 0, width: 200, height: 32)
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        func points(fromCM cm: CGFloat) -> CGFloat {
            guard let screen else { return cm * 37.8 }
            return NotchGeometry.points(fromCM: cm, on: screen)
        }

        // Flush with the screen's real top edge — the same position the
        // physical notch cutout itself starts at, so the pill sits directly
        // at/around the camera instead of appearing to hang below it.
        let topY = screenFrame.maxY

        let idleWidth = cutout.width + 2 * idleSideMarginPoints
        let idleHeight = cutout.height
        let idleFrame = CGRect(
            x: cutout.midX - idleWidth / 2,
            y: topY - idleHeight,
            width: idleWidth,
            height: idleHeight
        )

        let compactHeight = cutout.height
        let compactFrame = CGRect(
            x: cutout.minX - compactLeftMarginPoints,
            y: topY - compactHeight,
            width: cutout.width + compactLeftMarginPoints + compactRightMarginPoints,
            height: compactHeight
        )

        let expandedWidth = cutout.width + 2 * points(fromCM: expandedSideMarginCM)
        let expandedHeight = points(fromCM: expandedHeightCM)
        let expandedFrame = CGRect(
            x: cutout.midX - expandedWidth / 2,
            y: topY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )

        let panel = NotchPanel(
            contentRect: idleFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        // NSPanel (unlike NSWindow) defaults hidesOnDeactivate to true, which
        // silently hides this panel any time FootballNotch isn't the
        // frontmost app — i.e. almost always, for a background utility. That
        // was the real cause of the panel appearing to "belong" to whichever
        // app was active instead of staying independently on screen.
        panel.hidesOnDeactivate = false
        panel.idleFrame = idleFrame
        panel.compactFrame = compactFrame
        panel.expandedFrame = expandedFrame

        let hosting = ClickThroughHostingView(rootView: content.frame(maxWidth: .infinity, maxHeight: .infinity))
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = CGRect(origin: .zero, size: idleFrame.size)
        panel.contentView = hosting
        panel.setFrame(idleFrame, display: true)
        panel.orderFrontRegardless()
        panel.startHoverPolling()
        return panel
    }

    /// Switches between the three physical frames (idle / compact / expanded).
    /// The app layer maps its own display mode onto one of these — NotchPanel
    /// itself stays football-agnostic.
    func setVisualState(_ state: VisualState, animated: Bool = true) {
        guard state != currentState else { return }
        currentState = state
        let target = frame(for: state)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: true)
        }
    }

    private func frame(for state: VisualState) -> CGRect {
        switch state {
        case .idle: return idleFrame
        case .compact: return compactFrame
        case .expanded: return expandedFrame
        }
    }

    private func startHoverPolling() {
        hoverPollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollMouseLocation()
        }
        // .common so polling keeps running while a menu is open or the user
        // is mid-drag elsewhere — the default .default mode pauses during those.
        RunLoop.main.add(timer, forMode: .common)
        hoverPollTimer = timer
    }

    private func pollMouseLocation() {
        // Test against whichever frame is the CURRENT target state, not the
        // panel's mid-animation frame, so hover detection doesn't flicker
        // while the resize animation is running.
        let target = frame(for: currentState)
        let isInside = target.contains(NSEvent.mouseLocation)
        guard isInside != isMouseInsideNotch else { return }
        isMouseInsideNotch = isInside
        NotificationCenter.default.post(
            name: isInside ? Self.mouseEnteredNotification : Self.mouseExitedNotification,
            object: self
        )
    }

    deinit {
        hoverPollTimer?.invalidate()
    }
}

/// Lets the first click on a match row register immediately instead of being
/// swallowed to just focus the window (AppKit's default for non-key windows).
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
