import XCTest
@testable import FootballNotch

final class GoalSoundPlayerTests: XCTestCase {
    func test_systemSoundName_forSupportedTeam_isHero() {
        XCTAssertEqual(GoalSoundPlayer.systemSoundName(isForSupportedTeam: true), "Hero")
    }

    func test_systemSoundName_forOpponent_isBasso() {
        XCTAssertEqual(GoalSoundPlayer.systemSoundName(isForSupportedTeam: false), "Basso")
    }
}
