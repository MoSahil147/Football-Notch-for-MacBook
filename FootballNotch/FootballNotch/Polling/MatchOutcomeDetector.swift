import Foundation

enum MatchOutcome: Equatable {
    case won
    case lost
    case drew
}

/// Pure logic for the full-time result of the followed match, relative to
/// whichever team the user said they support — separate from GoalDiffDetector,
/// which only cares about individual goals, not the final result.
enum MatchOutcomeDetector {
    static func outcome(for match: Match, supportedTeamID: String?) -> MatchOutcome? {
        guard match.status == .finished, let supportedTeamID else { return nil }

        let supportedScore: Int
        let opponentScore: Int
        if match.homeTeam.id == supportedTeamID {
            supportedScore = match.homeScore
            opponentScore = match.awayScore
        } else if match.awayTeam.id == supportedTeamID {
            supportedScore = match.awayScore
            opponentScore = match.homeScore
        } else {
            return nil
        }

        if supportedScore > opponentScore { return .won }
        if supportedScore < opponentScore { return .lost }
        return .drew
    }
}
