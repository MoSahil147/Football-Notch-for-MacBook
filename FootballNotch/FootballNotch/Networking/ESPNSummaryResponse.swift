import Foundation

struct ESPNSummaryResponse: Decodable {
    let boxscore: ESPNBoxscore?
}

struct ESPNBoxscore: Decodable {
    let teams: [ESPNStatTeam]?
}

struct ESPNStatTeam: Decodable {
    let homeAway: String?
    let statistics: [ESPNStatEntry]?
}

struct ESPNStatEntry: Decodable {
    let name: String
    let displayValue: String
}

extension ESPNSummaryResponse {
    func toMatchStats() -> MatchStats {
        func value(_ name: String, homeAway: String) -> Int? {
            boxscore?.teams?
                .first(where: { $0.homeAway == homeAway })?
                .statistics?
                .first(where: { $0.name == name })
                .flatMap { Int($0.displayValue.filter { $0.isNumber }) }
        }

        return MatchStats(
            possessionHome: value("possessionPct", homeAway: "home"),
            possessionAway: value("possessionPct", homeAway: "away"),
            shotsHome: value("totalShots", homeAway: "home"),
            shotsAway: value("totalShots", homeAway: "away"),
            shotsOnTargetHome: value("shotsOnTarget", homeAway: "home"),
            shotsOnTargetAway: value("shotsOnTarget", homeAway: "away"),
            foulsHome: value("fouls", homeAway: "home"),
            foulsAway: value("fouls", homeAway: "away")
        )
    }
}
