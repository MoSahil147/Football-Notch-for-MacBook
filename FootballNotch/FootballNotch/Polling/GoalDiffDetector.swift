import Foundation

enum GoalSide {
    case home, away
}

struct GoalEvent: Equatable {
    let matchID: String
    let side: GoalSide
    let newHomeScore: Int
    let newAwayScore: Int
}

enum GoalDiffDetector {
    static func detectGoal(previous: Match?, current: Match) -> GoalEvent? {
        guard let previous, previous.id == current.id else { return nil }

        if current.homeScore > previous.homeScore {
            return GoalEvent(matchID: current.id, side: .home, newHomeScore: current.homeScore, newAwayScore: current.awayScore)
        }
        if current.awayScore > previous.awayScore {
            return GoalEvent(matchID: current.id, side: .away, newHomeScore: current.homeScore, newAwayScore: current.awayScore)
        }
        return nil
    }
}
