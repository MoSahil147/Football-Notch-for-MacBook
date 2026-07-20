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
    /// Consecutive polls where the followed match wasn't found in ESPN's
    /// data at all (a stale ID that's rolled off the API, not just a normal
    /// pre-kickoff/post-finish transition). A few consecutive misses, not
    /// just one, before giving up — a single miss is more likely a
    /// transient fetch failure for that one slug than the match truly
    /// being gone.
    private var consecutiveMissesForFollowed = 0
    private static let missesBeforeAutoUnfollow = 3

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

        // Not just strictly-live matches: also anything scheduled to kick
        // off within the next 15 minutes, so the picker shows a match before
        // ESPN itself has flipped its status to live, not only after.
        let now = Date()
        let displayable = allMatches.filter { $0.isDisplayable(asOf: now) }
        liveMatches = displayable.isEmpty ? liveMatches : displayable

        if let followedID = store.followedMatchID {
            if let current = allMatches.first(where: { $0.id == followedID }) {
                consecutiveMissesForFollowed = 0
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
            } else {
                // The followed match wasn't in this poll's data at all —
                // e.g. a stale ID left over from a much earlier session, or
                // one that's rolled off ESPN's default scoreboard window.
                // Without this, the app would stay "stuck" tracking a
                // phantom match forever, rendering nothing useful, with no
                // way back to idle short of manually clearing state.
                consecutiveMissesForFollowed += 1
                if consecutiveMissesForFollowed >= Self.missesBeforeAutoUnfollow {
                    unfollow()
                    consecutiveMissesForFollowed = 0
                }
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
