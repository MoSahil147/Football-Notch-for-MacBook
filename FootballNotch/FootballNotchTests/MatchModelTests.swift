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
}
