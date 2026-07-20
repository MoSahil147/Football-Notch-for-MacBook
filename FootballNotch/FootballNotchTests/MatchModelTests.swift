import XCTest
@testable import FootballNotch

final class MatchModelTests: XCTestCase {
    func test_match_equality_ignoresNothingRelevant() {
        let barca = Team(id: "83", shortName: "BAR", crestURL: nil)
        let real = Team(id: "86", shortName: "RMA", crestURL: nil)
        let m1 = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 2, awayScore: 1, status: .live(minute: 60))
        let m2 = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 2, awayScore: 1, status: .live(minute: 60))
        XCTAssertEqual(m1, m2)
    }

    func test_match_inequality_whenScoreChanges() {
        let barca = Team(id: "83", shortName: "BAR", crestURL: nil)
        let real = Team(id: "86", shortName: "RMA", crestURL: nil)
        let before = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 2, awayScore: 1, status: .live(minute: 60))
        let after = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 3, awayScore: 1, status: .live(minute: 61))
        XCTAssertNotEqual(before, after)
    }

    private func match(status: MatchStatus) -> Match {
        Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
              homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
              awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
              homeScore: 0, awayScore: 0, status: status)
    }

    func test_isDisplayable_liveMatch_alwaysTrue() {
        let now = Date()
        XCTAssertTrue(match(status: .live(minute: 60)).isDisplayable(asOf: now))
    }

    func test_isDisplayable_finishedOrPostponed_alwaysFalse() {
        let now = Date()
        XCTAssertFalse(match(status: .finished).isDisplayable(asOf: now))
        XCTAssertFalse(match(status: .postponed).isDisplayable(asOf: now))
    }

    func test_isDisplayable_scheduledWithin15Minutes_true() {
        let now = Date()
        let kickoff = now.addingTimeInterval(10 * 60) // kicks off in 10 minutes
        XCTAssertTrue(match(status: .scheduled(kickoff)).isDisplayable(asOf: now))
    }

    func test_isDisplayable_scheduledMoreThan15MinutesAway_false() {
        let now = Date()
        let kickoff = now.addingTimeInterval(20 * 60) // kicks off in 20 minutes
        XCTAssertFalse(match(status: .scheduled(kickoff)).isDisplayable(asOf: now))
    }

    func test_isDisplayable_respectsCustomWindow() {
        let now = Date()
        let kickoff = now.addingTimeInterval(25 * 60)
        XCTAssertTrue(match(status: .scheduled(kickoff)).isDisplayable(asOf: now, upcomingWindow: 30 * 60))
    }
}
