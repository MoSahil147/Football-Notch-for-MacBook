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

    func test_followWithMatch_populatesFollowedMatchImmediately_beforeAnyPoll() {
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: FakeESPNClient(), store: store)
        let picked = match(home: 0, away: 0)

        service.follow(picked)

        XCTAssertEqual(service.followedMatch, picked)
        XCTAssertEqual(store.followedMatchID, "1")
    }

    func test_followWithMatch_fetchesStatsImmediately_beforeAnyPoll() async {
        let client = FakeESPNClient()
        client.statsToReturn = MatchStats(possessionHome: 60, possessionAway: 40, shotsHome: nil, shotsAway: nil, shotsOnTargetHome: nil, shotsOnTargetAway: nil, foulsHome: nil, foulsAway: nil)
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)

        service.follow(match(home: 0, away: 0))
        // follow(_:) fires an unawaited Task internally (fire-and-forget, so
        // the caller isn't blocked waiting on a network call) — give it a
        // moment to actually run before asserting.
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(service.followedMatchStats?.possessionHome, 60)
    }

    func test_pollOnce_populatesLiveMatchesAcrossSlugs() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)

        await service.pollOnce()

        XCTAssertEqual(service.liveMatches.count, 1)
    }

    func test_pollOnce_includesMatchesKickingOffWithin15Minutes() async {
        let client = FakeESPNClient()
        let upcoming = Match(id: "2", competitionSlug: "esp.1", competitionName: "La Liga",
                              homeTeam: Team(id: "1", shortName: "ATM", crestURL: nil),
                              awayTeam: Team(id: "2", shortName: "SEV", crestURL: nil),
                              homeScore: 0, awayScore: 0,
                              status: .scheduled(Date().addingTimeInterval(10 * 60)))
        client.matchesBySlug["esp.1"] = [upcoming]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)

        await service.pollOnce()

        XCTAssertEqual(service.liveMatches, [upcoming])
    }

    func test_pollOnce_excludesMatchesScheduledMoreThan15MinutesOut() async {
        let client = FakeESPNClient()
        let farOff = Match(id: "2", competitionSlug: "esp.1", competitionName: "La Liga",
                            homeTeam: Team(id: "1", shortName: "ATM", crestURL: nil),
                            awayTeam: Team(id: "2", shortName: "SEV", crestURL: nil),
                            homeScore: 0, awayScore: 0,
                            status: .scheduled(Date().addingTimeInterval(60 * 60)))
        client.matchesBySlug["esp.1"] = [farOff]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)

        await service.pollOnce()

        XCTAssertTrue(service.liveMatches.isEmpty)
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

    func test_pollOnce_appendsToGoalEventLog_andFollowResetsIt() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        await service.pollOnce() // establish baseline

        client.matchesBySlug["esp.1"] = [match(home: 1, away: 0)]
        await service.pollOnce()
        client.matchesBySlug["esp.1"] = [match(home: 1, away: 1)]
        await service.pollOnce()

        XCTAssertEqual(service.followedMatchGoalEvents.count, 2)
        XCTAssertEqual(service.followedMatchGoalEvents.last, GoalEvent(matchID: "1", side: .away, newHomeScore: 1, newAwayScore: 1))

        service.follow(matchID: "2")
        XCTAssertTrue(service.followedMatchGoalEvents.isEmpty)
    }

    func test_pollOnce_firesMatchFinished_whenFollowedMatchEnds() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 1, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        store.supportedTeamID = "83" // home team
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        await service.pollOnce() // establish baseline (still live)

        var receivedOutcome: MatchOutcome?
        service.onMatchFinished = { receivedOutcome = $0 }
        client.matchesBySlug["esp.1"] = [
            Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
                  homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
                  awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
                  homeScore: 1, awayScore: 0, status: .finished)
        ]
        await service.pollOnce()

        XCTAssertEqual(receivedOutcome, .won)

        // Doesn't fire again on a later poll once already finished.
        receivedOutcome = nil
        await service.pollOnce()
        XCTAssertNil(receivedOutcome)
    }

    func test_pollOnce_toleratesOneOrTwoMissesForFollowedMatch_withoutUnfollowing() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        await service.pollOnce() // establish baseline (found)

        // Two consecutive misses — a likely transient blip, not "gone".
        client.matchesBySlug["esp.1"] = []
        await service.pollOnce()
        await service.pollOnce()

        XCTAssertEqual(store.followedMatchID, "1")
    }

    func test_pollOnce_autoUnfollowsAfterThreeConsecutiveMisses() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        await service.pollOnce() // establish baseline (found)

        client.matchesBySlug["esp.1"] = []
        await service.pollOnce()
        await service.pollOnce()
        await service.pollOnce() // 3rd consecutive miss

        XCTAssertNil(store.followedMatchID)
        XCTAssertNil(service.followedMatch)
    }

    func test_pollOnce_keepsShowingFinishedMatch_withinPostMatchWindow() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 1, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        let start = Date()
        await service.pollOnce(now: start) // establish baseline (still live)

        client.matchesBySlug["esp.1"] = [
            Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
                  homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
                  awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
                  homeScore: 1, awayScore: 0, status: .finished)
        ]
        await service.pollOnce(now: start) // finishes here

        // Still well within the post-match display window (10 minutes later).
        await service.pollOnce(now: start.addingTimeInterval(10 * 60))

        XCTAssertEqual(store.followedMatchID, "1")
        XCTAssertNotNil(service.followedMatch)
    }

    func test_pollOnce_revertsToIdle_afterPostMatchWindowExpires() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 1, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        let start = Date()
        await service.pollOnce(now: start) // establish baseline (still live)

        client.matchesBySlug["esp.1"] = [
            Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
                  homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
                  awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
                  homeScore: 1, awayScore: 0, status: .finished)
        ]
        await service.pollOnce(now: start) // finishes here

        // Past the 20-minute post-match display window.
        await service.pollOnce(now: start.addingTimeInterval(21 * 60))

        XCTAssertNil(store.followedMatchID)
        XCTAssertNil(service.followedMatch)
    }
}
