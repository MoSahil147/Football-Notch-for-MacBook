import XCTest
@testable import FootballNotch

final class NotchGeometryTests: XCTestCase {
    func test_notchFrame_returnsNilWhenNoSafeAreaInsets() {
        // A screen with zero top safe-area inset (no notch, e.g. external display)
        let frame = NotchGeometry.notchFrame(topSafeAreaInset: 0, screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertNil(frame)
    }

    func test_notchFrame_returnsCenteredRectWhenInsetPresent() {
        // MacBook Pro 14"/16" notch: ~32pt top inset
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.notchFrame(topSafeAreaInset: 32, screenFrame: screenFrame)
        XCTAssertNotNil(frame)
        XCTAssertEqual(frame!.height, 32, accuracy: 0.1)
        // Notch should be horizontally centered on screen
        XCTAssertEqual(frame!.midX, screenFrame.midX, accuracy: 1.0)
    }
}
