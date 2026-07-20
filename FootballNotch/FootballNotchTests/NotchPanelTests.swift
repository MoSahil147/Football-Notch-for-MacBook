import XCTest
@testable import FootballNotch
import SwiftUI

final class NotchPanelTests: XCTestCase {
    func test_makeAndShow_startsIdleCenteredTightOnNotch() throws {
        guard let screen = NotchGeometry.notchedScreen() else {
            throw XCTSkip("No notched screen available in test environment")
        }
        let panel = NotchPanel.makeAndShow(content: Text("test"))
        let cutout = NotchGeometry.notchFrame(for: screen) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        // Idle is small and centered tight to the camera, matching the
        // original look — not the wider compact-tracking size.
        XCTAssertEqual(panel.frame.midX, cutout.midX, accuracy: 1.0)
        XCTAssertLessThan(panel.frame.width, cutout.width + 60)
        XCTAssertEqual(panel.frame.minY, cutout.minY, accuracy: 1.0)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertEqual(panel.level, .screenSaver)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        panel.close()
    }

    func test_setVisualState_compact_widerThanIdleButNarrowerThanExpanded() throws {
        guard NotchGeometry.notchedScreen() != nil else {
            throw XCTSkip("No notched screen available in test environment")
        }
        let panel = NotchPanel.makeAndShow(content: Text("test"))
        let idleFrame = panel.frame

        panel.setVisualState(.compact, animated: false)
        let compactFrame = panel.frame
        XCTAssertGreaterThan(compactFrame.width, idleFrame.width)
        XCTAssertEqual(compactFrame.height, idleFrame.height, accuracy: 1.0)

        panel.setVisualState(.expanded, animated: false)
        XCTAssertGreaterThan(panel.frame.width, compactFrame.width)
        XCTAssertGreaterThan(panel.frame.height, compactFrame.height)

        panel.setVisualState(.idle, animated: false)
        XCTAssertEqual(panel.frame.width, idleFrame.width, accuracy: 1.0)
        panel.close()
    }
}
