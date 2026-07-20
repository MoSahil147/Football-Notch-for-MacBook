import XCTest
@testable import FootballNotch

final class FakeESPNClient: ESPNClientProtocol {
    var matchesBySlug: [String: [Match]] = [:]
    var statsToReturn: MatchStats = MatchStats(possessionHome: nil, possessionAway: nil, shotsHome: nil, shotsAway: nil, shotsOnTargetHome: nil, shotsOnTargetAway: nil, foulsHome: nil, foulsAway: nil)

    func fetchMatches(competitionSlug: String, competitionName: String) async throws -> [Match] {
        matchesBySlug[competitionSlug] ?? []
    }

    func fetchStats(competitionSlug: String, eventID: String) async throws -> MatchStats {
        statsToReturn
    }
}

@MainActor
final class MatchPollingServiceTests: XCTestCase {
    private func match(id: String = "1", home: Int, away: Int) -> Match {
        Match(id: id, competitionSlug: "esp.1", competitionName: "La Liga",
              homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
              awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
              homeScore: home, awayScore: away, status: .live(minute: 10))
    }

    func test_pollOnce_populatesLiveMatchesAcrossSlugs() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)

        await service.pollOnce()

        XCTAssertEqual(service.liveMatches.count, 1)
    }

    func test_pollOnce_firesGoalEventWhenFollowedMatchScoreIncreases() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        await service.pollOnce() // establish baseline

        var receivedEvent: GoalEvent?
        service.onGoalEvent = { receivedEvent = $0 }
        client.matchesBySlug["esp.1"] = [match(home: 1, away: 0)]
        await service.pollOnce()

        XCTAssertEqual(receivedEvent, GoalEvent(matchID: "1", side: .home, newHomeScore: 1, newAwayScore: 0))
        XCTAssertEqual(service.followedMatch?.homeScore, 1)
    }
}
