import XCTest
@testable import FootballNotch

final class GoalDiffDetectorTests: XCTestCase {
    private func match(home: Int, away: Int) -> Match {
        Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
              homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
              awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
              homeScore: home, awayScore: away, status: .live(minute: 10))
    }

    func test_noPreviousMatch_returnsNilEvenWithScore() {
        XCTAssertNil(GoalDiffDetector.detectGoal(previous: nil, current: match(home: 1, away: 0)))
    }

    func test_homeScoreIncrease_detectedAsHomeGoal() {
        let event = GoalDiffDetector.detectGoal(previous: match(home: 0, away: 0), current: match(home: 1, away: 0))
        XCTAssertEqual(event, GoalEvent(matchID: "1", side: .home, newHomeScore: 1, newAwayScore: 0))
    }

    func test_awayScoreIncrease_detectedAsAwayGoal() {
        let event = GoalDiffDetector.detectGoal(previous: match(home: 1, away: 0), current: match(home: 1, away: 1))
        XCTAssertEqual(event, GoalEvent(matchID: "1", side: .away, newHomeScore: 1, newAwayScore: 1))
    }

    func test_noScoreChange_returnsNil() {
        XCTAssertNil(GoalDiffDetector.detectGoal(previous: match(home: 1, away: 1), current: match(home: 1, away: 1)))
    }

    func test_scoreDecrease_treatedAsNoGoal() {
        // Defensive: a correction/rollback from ESPN should never fire a goal alert
        XCTAssertNil(GoalDiffDetector.detectGoal(previous: match(home: 2, away: 1), current: match(home: 1, away: 1)))
    }
}
