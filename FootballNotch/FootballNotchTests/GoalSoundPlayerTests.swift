import XCTest
@testable import FootballNotch

final class GoalSoundPlayerTests: XCTestCase {
    func test_soundFileName_forSupportedTeam_isCelebration() {
        XCTAssertEqual(GoalSoundPlayer.soundFileName(isForSupportedTeam: true), "goal_celebration.caf")
    }

    func test_soundFileName_forOpponent_isConcede() {
        XCTAssertEqual(GoalSoundPlayer.soundFileName(isForSupportedTeam: false), "goal_concede.caf")
    }
}
