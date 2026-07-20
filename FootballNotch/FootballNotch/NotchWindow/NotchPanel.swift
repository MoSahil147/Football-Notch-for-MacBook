import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    static let mouseEnteredNotification = Notification.Name("NotchPanel.mouseEntered")
    static let mouseExitedNotification = Notification.Name("NotchPanel.mouseExited")

    enum VisualState {
        case resting
        case expanded
    }

    // Physical layout matched to a real-device spec rather than derived from
    // measured content size: the pill's top edge sits a fixed physical
    // distance below the screen's top edge (the same row the camera notch
    // occupies), and expands downward + sideways to an exact physical block
    // on hover. Fixed target frames (vs. the earlier content-driven
    // measure->resize->re-measure loop) is also what fixed the flicker and
    // hover-breaking-after-first-cycle bugs.
    private static let topInsetCM: CGFloat = 1
    private static let expandedHeightCM: CGFloat = 4
    private static let expandedSideMarginCM: CGFloat = 2
    // Resting state isn't given a physical spec — it only needs enough
    // overflow past the notch's dead-pixel cutout for the idle emoji (at the
    // left edge) to land on real, visible pixels.
    private static let restingSideMarginPoints: CGFloat = 20

    private var restingFrame: CGRect = .zero
    private var expandedFrame: CGRect = .zero
    private var currentState: VisualState = .resting

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

        let topY = screenFrame.maxY - points(fromCM: topInsetCM)

        let restingWidth = cutout.width + 2 * restingSideMarginPoints
        let restingHeight = cutout.height
        let restingFrame = CGRect(
            x: cutout.midX - restingWidth / 2,
            y: topY - restingHeight,
            width: restingWidth,
            height: restingHeight
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
            contentRect: restingFrame,
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
        panel.restingFrame = restingFrame
        panel.expandedFrame = expandedFrame

        let hosting = ClickThroughHostingView(rootView: content.frame(maxWidth: .infinity, maxHeight: .infinity))
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = CGRect(origin: .zero, size: restingFrame.size)
        panel.contentView = hosting
        panel.setFrame(restingFrame, display: true)
        panel.orderFrontRegardless()
        panel.startHoverPolling()
        return panel
    }

    /// Switches between the resting (notch-row) and expanded (hover) physical
    /// frames. The app layer maps its own display mode to one of these two
    /// states — NotchPanel itself stays football-agnostic.
    func setVisualState(_ state: VisualState, animated: Bool = true) {
        guard state != currentState else { return }
        currentState = state
        let target = state == .resting ? restingFrame : expandedFrame
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
        // Test against whichever frame is the CURRENT target state (resting
        // or expanded), not the panel's mid-animation frame, so hover
        // detection doesn't flicker while the resize animation is running.
        let target = currentState == .resting ? restingFrame : expandedFrame
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
