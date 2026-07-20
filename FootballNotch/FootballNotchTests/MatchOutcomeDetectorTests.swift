import XCTest
@testable import FootballNotch

final class MatchOutcomeDetectorTests: XCTestCase {
    private func match(status: MatchStatus, home: Int, away: Int) -> Match {
        Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
              homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
              awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
              homeScore: home, awayScore: away, status: status)
    }

    func test_notFinished_returnsNil() {
        let m = match(status: .live(minute: 60), home: 2, away: 0)
        XCTAssertNil(MatchOutcomeDetector.outcome(for: m, supportedTeamID: "83"))
    }

    func test_noSupportedTeam_returnsNil() {
        let m = match(status: .finished, home: 2, away: 0)
        XCTAssertNil(MatchOutcomeDetector.outcome(for: m, supportedTeamID: nil))
    }

    func test_supportedHomeTeamScoresMore_returnsWon() {
        let m = match(status: .finished, home: 2, away: 0)
        XCTAssertEqual(MatchOutcomeDetector.outcome(for: m, supportedTeamID: "83"), .won)
    }

    func test_supportedAwayTeamScoresLess_returnsLost() {
        let m = match(status: .finished, home: 2, away: 0)
        XCTAssertEqual(MatchOutcomeDetector.outcome(for: m, supportedTeamID: "86"), .lost)
    }

    func test_equalScores_returnsDrew() {
        let m = match(status: .finished, home: 1, away: 1)
        XCTAssertEqual(MatchOutcomeDetector.outcome(for: m, supportedTeamID: "83"), .drew)
    }
}
