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
}
