import Foundation

@MainActor
final class MatchPollingService: ObservableObject {
    @Published private(set) var liveMatches: [Match] = []
    @Published private(set) var followedMatch: Match?
    @Published private(set) var followedMatchStats: MatchStats?
    /// Team-level goal log for the followed match (who scored, not the
    /// scorer's name — ESPN's summary endpoint isn't parsed for individual
    /// scorers yet, so this is the "who scored" info available today).
    @Published private(set) var followedMatchGoalEvents: [GoalEvent] = []

    var onGoalEvent: ((GoalEvent) -> Void)?
    /// Fires once, the moment the followed match transitions to finished —
    /// distinct from onGoalEvent, which fires per-goal during play.
    var onMatchFinished: ((MatchOutcome) -> Void)?

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
        followedMatchGoalEvents = []
    }

    /// Same as follow(matchID:), but also populates `followedMatch`
    /// immediately from data the caller already has (the match the user just
    /// tapped in the picker) instead of leaving it nil until the next poll
    /// cycle — without this, the compact pill has nothing to render for up
    /// to `activeInterval` seconds right after confirming a match. Also
    /// kicks off an immediate stats fetch for the same reason — otherwise
    /// followedMatchStats stays nil (no stats shown at all) until the next
    /// scheduled poll, up to activeInterval seconds later.
    func follow(_ match: Match) {
        store.followedMatchID = match.id
        followedMatch = match
        followedMatchGoalEvents = []
        Task { await refreshStats(for: match) }
    }

    private func refreshStats(for match: Match) async {
        if let stats = try? await client.fetchStats(competitionSlug: match.competitionSlug, eventID: match.id) {
            followedMatchStats = stats
        }
    }

    func unfollow() {
        store.clear()
        followedMatch = nil
        followedMatchStats = nil
        followedMatchGoalEvents = []
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
                followedMatchGoalEvents.append(event)
                onGoalEvent?(event)
            }
            if previous?.status != .finished,
               let outcome = MatchOutcomeDetector.outcome(for: current, supportedTeamID: store.supportedTeamID) {
                onMatchFinished?(outcome)
            }
            lastKnownByID[followedID] = current
            followedMatch = current

            await refreshStats(for: current)
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
