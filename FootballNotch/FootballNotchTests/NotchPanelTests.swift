import XCTest
@testable import FootballNotch
import SwiftUI

final class NotchPanelTests: XCTestCase {
    func test_makeAndShow_positionsRestingPanelCenteredOnNotch() throws {
        guard let screen = NotchGeometry.notchedScreen() else {
            throw XCTSkip("No notched screen available in test environment")
        }
        let panel = NotchPanel.makeAndShow(content: Text("test"))
        let cutout = NotchGeometry.notchFrame(for: screen) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        XCTAssertEqual(panel.frame.midX, cutout.midX, accuracy: 1.0)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertEqual(panel.level, .screenSaver)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        panel.close()
    }

    func test_setVisualState_expanded_growsWiderAndTallerThanResting() throws {
        guard NotchGeometry.notchedScreen() != nil else {
            throw XCTSkip("No notched screen available in test environment")
        }
        let panel = NotchPanel.makeAndShow(content: Text("test"))
        let restingFrame = panel.frame

        panel.setVisualState(.expanded, animated: false)
        XCTAssertGreaterThan(panel.frame.width, restingFrame.width)
        XCTAssertGreaterThan(panel.frame.height, restingFrame.height)
        XCTAssertEqual(panel.frame.midX, restingFrame.midX, accuracy: 1.0)

        panel.setVisualState(.resting, animated: false)
        XCTAssertEqual(panel.frame.width, restingFrame.width, accuracy: 1.0)
        XCTAssertEqual(panel.frame.height, restingFrame.height, accuracy: 1.0)
        panel.close()
    }
}
