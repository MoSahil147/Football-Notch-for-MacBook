import Foundation

enum MatchStatus: Equatable {
    case scheduled(Date)
    case live(minute: Int)
    case finished
    case postponed
}

struct Match: Identifiable, Equatable {
    let id: String
    let competitionSlug: String
    let competitionName: String
    let homeTeam: Team
    let awayTeam: Team
    let homeScore: Int
    let awayScore: Int
    let status: MatchStatus

    var isLive: Bool {
        if case .live = status { return true }
        return false
    }

    /// Whether this match should show up in the picker: already live, or
    /// scheduled to kick off within `upcomingWindow` of `now` (default 15
    /// minutes) — so people can find and select a match just before it
    /// starts, not only once ESPN has already flipped its status to live.
    /// `now` is a parameter (not read internally) so this stays pure and
    /// testable without depending on the wall clock.
    func isDisplayable(asOf now: Date, upcomingWindow: TimeInterval = 15 * 60) -> Bool {
        switch status {
        case .live:
            return true
        case .scheduled(let kickoff):
            let timeUntilKickoff = kickoff.timeIntervalSince(now)
            return timeUntilKickoff <= upcomingWindow && timeUntilKickoff > -upcomingWindow
        case .finished, .postponed:
            return false
        }
    }
}
