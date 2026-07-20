import XCTest
@testable import FootballNotch

@MainActor
final class AppStateTests: XCTestCase {
    func test_startsHiddenWhenNoMatchFollowed() {
        let state = AppState(isFollowingMatch: { false })
        XCTAssertEqual(state.mode, .hidden)
    }

    func test_startsCompactPillWhenFollowingMatch() {
        let state = AppState(isFollowingMatch: { true })
        XCTAssertEqual(state.mode, .compactPill)
    }

    func test_mouseEntered_switchesToHoverExpanded() {
        let state = AppState(isFollowingMatch: { true })
        state.mouseEntered()
        XCTAssertEqual(state.mode, .hoverExpanded)
    }

    func test_mouseExited_returnsToCompactPill() async {
        let state = AppState(isFollowingMatch: { true }, collapseDebounce: 0.02)
        state.mouseEntered()
        state.mouseExited()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(state.mode, .compactPill)
    }

    func test_mouseEntered_fromHidden_switchesToHoverExpanded() {
        // No match followed yet — hovering the stock notch must still reveal the picker.
        let state = AppState(isFollowingMatch: { false })
        state.mouseEntered()
        XCTAssertEqual(state.mode, .hoverExpanded)
    }

    func test_mouseExited_fromHiddenOrigin_returnsToHidden() async {
        let state = AppState(isFollowingMatch: { false }, collapseDebounce: 0.02)
        state.mouseEntered()
        state.mouseExited()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(state.mode, .hidden)
    }

    func test_mouseExited_thenReentered_withinDebounceWindow_staysExpanded() async {
        // Simulates the animated-resize flicker: a spurious exit/enter pair
        // firing in quick succession must not collapse the picker.
        let state = AppState(isFollowingMatch: { true }, collapseDebounce: 0.1)
        state.mouseEntered()
        state.mouseExited()
        try? await Task.sleep(nanoseconds: 20_000_000)
        state.mouseEntered()
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(state.mode, .hoverExpanded)
    }

    func test_goalAlert_autoCollapsesAfterDelay() async {
        let state = AppState(isFollowingMatch: { true }, goalAlertDuration: 0.05)
        let event = GoalEvent(matchID: "1", side: .home, newHomeScore: 1, newAwayScore: 0)
        state.showGoalAlert(event)
        XCTAssertEqual(state.mode, .goalAlert(event))
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(state.mode, .compactPill)
    }
}
