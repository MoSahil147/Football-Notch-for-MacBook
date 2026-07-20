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

    /// Regression test for the real shape of ESPN's live scoreboard API,
    /// verified 2026-07-20 against https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard —
    /// team crest is a single "logo" string field, NOT a "logos" array (the
    /// array shape this decoder originally assumed doesn't appear here at
    /// all, so crests were silently never loading from real data).
    func test_decodesScoreboard_usesSingularLogoField_matchingRealAPIShape() throws {
        let json = """
        {"events":[{"id":"401879301","status":{"type":{"state":"pre"}},"competitions":[{"competitors":[
          {"homeAway":"home","score":"0","team":{"id":"359","abbreviation":"ARS","logo":"https://a.espncdn.com/i/teamlogos/soccer/500/359.png"}},
          {"homeAway":"away","score":"0","team":{"id":"388","abbreviation":"COV","logo":"https://a.espncdn.com/i/teamlogos/soccer/500/388.png"}}
        ]}]}]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: json)
        let matches = decoded.toMatches(competitionName: "Premier League", competitionSlug: "eng.1")
        XCTAssertEqual(matches.first?.homeTeam.crestURL, URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/359.png"))
        XCTAssertEqual(matches.first?.awayTeam.crestURL, URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/388.png"))
    }
}
