import XCTest
@testable import FootballNotch

final class ESPNDecodingTests: XCTestCase {
    func test_decodesScoreboard_tolerantOfMissingStatisticsField() throws {
        let json = """
        {
          "events": [
            {
              "id": "6013",
              "status": { "type": { "state": "in", "shortDetail": "60'" } },
              "competitions": [
                {
                  "competitors": [
                    { "homeAway": "home", "score": "2", "team": { "id": "83", "abbreviation": "BAR", "logos": [{ "href": "https://example.com/barca.png" }] } },
                    { "homeAway": "away", "score": "1", "team": { "id": "86", "abbreviation": "RMA", "logos": [{ "href": "https://example.com/real.png" }] } }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: json)
        let matches = decoded.toMatches(competitionName: "La Liga", competitionSlug: "esp.1")

        XCTAssertEqual(matches.count, 1)
        let match = matches[0]
        XCTAssertEqual(match.homeScore, 2)
        XCTAssertEqual(match.awayScore, 1)
        XCTAssertEqual(match.homeTeam.shortName, "BAR")
        if case .live(let minute) = match.status {
            XCTAssertEqual(minute, 60)
        } else {
            XCTFail("Expected live status")
        }
    }

    func test_decodesScoreboard_toleratesMissingLogo() throws {
        let json = """
        {"events":[{"id":"1","status":{"type":{"state":"post"}},"competitions":[{"competitors":[
          {"homeAway":"home","score":"0","team":{"id":"1","abbreviation":"ENG"}},
          {"homeAway":"away","score":"0","team":{"id":"2","abbreviation":"FRA"}}
        ]}]}]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: json)
        let matches = decoded.toMatches(competitionName: "World Cup", competitionSlug: "fifa.world")
        XCTAssertEqual(matches.first?.homeTeam.crestURL, nil)
        XCTAssertEqual(matches.first?.status, .finished)
    }
}
