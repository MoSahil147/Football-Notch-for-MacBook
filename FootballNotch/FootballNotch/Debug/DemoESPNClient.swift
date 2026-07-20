#if DEBUG
import Foundation

/// A stand-in for `ESPNClient` that returns canned live-match data instead of
/// hitting the real ESPN API — so the full idle → pick-a-match →
/// compact-pill → hover-stats → goal-alert flow can be exercised end-to-end
/// through the real production pipeline (MatchPollingService,
/// GoalDiffDetector, AppState, etc.) without waiting for an actual live
/// match. Debug-only: this file is excluded from Release builds entirely by
/// the `#if DEBUG` wrapping it, so it can never activate for a real user.
///
/// Enable by adding an `FN_DEMO_MODE=1` environment variable to the Xcode
/// scheme (Product > Scheme > Edit Scheme > Run > Arguments >
/// Environment Variables) before running.
final class DemoESPNClient: ESPNClientProtocol {
    // Two matches from two different competitions, so the picker shows a
    // real cross-league choice — one La Liga, one Premier League — matching
    // how MatchPollingService actually polls each tracked slug separately.
    private let laLigaSlug = "esp.1"
    private let premierLeagueSlug = "eng.1"

    // Both matches start at kickoff (0') and tick forward one minute per
    // poll, independently — each incremented only when its own slug is
    // actually queried, so they stay accurate regardless of the order
    // ESPNEndpoints.trackedSlugs happens to poll competitions in.
    private var laLigaMinute = 0
    private var laLigaHomeScore = 0
    private var laLigaAwayScore = 0

    private var premierLeagueMinute = 0
    private var premierLeagueHomeScore = 0
    private var premierLeagueAwayScore = 0

    // Real crest URLs, matched to the correct team via ESPN's actual
    // /teams endpoint on 2026-07-20 (not just "an image that loads" — id 83
    // is genuinely Barcelona's own crest, 86 genuinely Real Madrid's; an
    // earlier version of this file accidentally reused Arsenal/Coventry's
    // crest URLs here, which loaded fine but showed the wrong team).
    private let laLigaHome = Team(
        id: "83", shortName: "BAR",
        crestURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/83.png")
    )
    private let laLigaAway = Team(
        id: "86", shortName: "RMA",
        crestURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/86.png")
    )
    private let premierLeagueHome = Team(
        id: "359", shortName: "ARS",
        crestURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/359.png")
    )
    private let premierLeagueAway = Team(
        id: "388", shortName: "COV",
        crestURL: URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/388.png")
    )

    func fetchMatches(competitionSlug: String, competitionName: String) async throws -> [Match] {
        switch competitionSlug {
        case laLigaSlug:
            // ~1 minute per poll while actively followed (12s interval) —
            // slower/more realistic-feeling than the old "3 minutes per
            // poll" version, and a goal roughly every 3rd poll (~36s).
            laLigaMinute = min(90, laLigaMinute + 1)
            if laLigaMinute % 3 == 0 && laLigaMinute > 0 {
                if laLigaMinute % 6 == 0 {
                    laLigaAwayScore += 1
                } else {
                    laLigaHomeScore += 1
                }
            }
            let match = Match(
                id: "demo-1",
                competitionSlug: laLigaSlug,
                competitionName: competitionName,
                homeTeam: laLigaHome,
                awayTeam: laLigaAway,
                homeScore: laLigaHomeScore,
                awayScore: laLigaAwayScore,
                status: .live(minute: laLigaMinute)
            )
            return [match]
        case premierLeagueSlug:
            premierLeagueMinute = min(90, premierLeagueMinute + 1)
            if premierLeagueMinute % 4 == 0 && premierLeagueMinute > 0 {
                if premierLeagueMinute % 8 == 0 {
                    premierLeagueAwayScore += 1
                } else {
                    premierLeagueHomeScore += 1
                }
            }
            let match = Match(
                id: "demo-2",
                competitionSlug: premierLeagueSlug,
                competitionName: competitionName,
                homeTeam: premierLeagueHome,
                awayTeam: premierLeagueAway,
                homeScore: premierLeagueHomeScore,
                awayScore: premierLeagueAwayScore,
                status: .live(minute: premierLeagueMinute)
            )
            return [match]
        default:
            return []
        }
    }

    func fetchStats(competitionSlug: String, eventID: String) async throws -> MatchStats {
        MatchStats(
            possessionHome: 58,
            possessionAway: 42,
            shotsHome: 11,
            shotsAway: 6,
            shotsOnTargetHome: 5,
            shotsOnTargetAway: 2,
            foulsHome: 7,
            foulsAway: 9
        )
    }
}
#endif
