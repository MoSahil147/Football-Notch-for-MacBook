import AppKit

enum NotchGeometry {
    /// Approximate on-screen width of the physical notch cutout across current
    /// notched MacBook models. Real notch width isn't exposed directly by AppKit,
    /// so we use a fixed width and rely on the safe-area inset for height/presence.
    static let approximateNotchWidth: CGFloat = 200

    static func notchFrame(topSafeAreaInset: CGFloat, screenFrame: CGRect) -> CGRect? {
        guard topSafeAreaInset > 0 else { return nil }
        let width = approximateNotchWidth
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - topSafeAreaInset
        return CGRect(x: x, y: y, width: width, height: topSafeAreaInset)
    }

    /// Convenience overload used by production code, reading the real screen's inset.
    static func notchFrame(for screen: NSScreen) -> CGRect? {
        notchFrame(topSafeAreaInset: screen.safeAreaInsets.top, screenFrame: screen.frame)
    }

    /// The physical display that actually has the notch. `NSScreen.main` is
    /// whichever screen currently holds the key window/menu bar — with an
    /// external monitor connected and focused, that's often not the built-in
    /// display at all, which silently breaks every position calculated from
    /// it (this was the root cause of the panel appearing off-center).
    static func notchedScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    /// Converts a physical length in centimeters to points on `screen`, using
    /// the display's real physical size (via CGDisplayScreenSize) rather than
    /// its point resolution, so the on-screen measurement is accurate
    /// regardless of Retina scaling.
    static func points(fromCM cm: CGFloat, on screen: NSScreen) -> CGFloat {
        let fallbackPointsPerCM: CGFloat = 37.8 // ~96pt/inch, used only if physical size is unavailable
        guard
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return cm * fallbackPointsPerCM }
        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        let physicalSizeMM = CGDisplayScreenSize(displayID)
        guard physicalSizeMM.width > 0 else { return cm * fallbackPointsPerCM }
        let pointsPerMM = screen.frame.width / physicalSizeMM.width
        return cm * 10 * pointsPerMM
    }
}
