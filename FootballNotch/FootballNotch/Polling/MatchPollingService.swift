import Foundation

@MainActor
final class MatchPollingService: ObservableObject {
    @Published private(set) var liveMatches: [Match] = []
    @Published private(set) var followedMatch: Match?
    @Published private(set) var followedMatchStats: MatchStats?

    var onGoalEvent: ((GoalEvent) -> Void)?

    private let client: ESPNClientProtocol
    private let store: FollowedMatchStore
    private var lastKnownByID: [String: Match] = [:]
    private var pollTask: Task<Void, Never>?

    init(client: ESPNClientProtocol, store: FollowedMatchStore) {
        self.client = client
        self.store = store
    }

    func follow(matchID: String) {
        store.followedMatchID = matchID
    }

    func unfollow() {
        store.clear()
        followedMatch = nil
        followedMatchStats = nil
    }

    func pollOnce() async {
        var allMatches: [Match] = []
        for slug in ESPNEndpoints.trackedSlugs {
            let competitionName = Self.displayName(for: slug)
            if let matches = try? await client.fetchMatches(competitionSlug: slug, competitionName: competitionName) {
                allMatches.append(contentsOf: matches)
            }
            // Failed fetches are silently skipped — last known good state (below) stays intact.
        }

        let liveOnly = allMatches.filter(\.isLive)
        liveMatches = liveOnly.isEmpty ? liveMatches : liveOnly

        if let followedID = store.followedMatchID,
           let current = allMatches.first(where: { $0.id == followedID }) {
            let previous = lastKnownByID[followedID]
            if let event = GoalDiffDetector.detectGoal(previous: previous, current: current) {
                onGoalEvent?(event)
            }
            lastKnownByID[followedID] = current
            followedMatch = current

            if let stats = try? await client.fetchStats(competitionSlug: current.competitionSlug, eventID: current.id) {
                followedMatchStats = stats
            }
        }
    }

    func startPolling(idleInterval: TimeInterval = 40, activeInterval: TimeInterval = 12) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await pollOnce()
                let interval = store.followedMatchID != nil ? activeInterval : idleInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
    }

    private static func displayName(for slug: String) -> String {
        switch slug {
        case "eng.1": return "Premier League"
        case "esp.1": return "La Liga"
        case "ita.1": return "Serie A"
        case "ger.1": return "Bundesliga"
        case "fra.1": return "Ligue 1"
        case "uefa.champions": return "Champions League"
        case "uefa.europa": return "Europa League"
        case "fifa.world": return "World Cup"
        default: return slug
        }
    }
}
