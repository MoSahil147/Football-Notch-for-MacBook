import Foundation

struct ESPNScoreboardResponse: Decodable {
    let events: [ESPNEvent]
}

struct ESPNEvent: Decodable {
    let id: String
    let status: ESPNStatus
    let competitions: [ESPNCompetition]
}

struct ESPNStatus: Decodable {
    let type: ESPNStatusType
}

struct ESPNStatusType: Decodable {
    let state: String // "pre", "in", "post"
    let shortDetail: String?
}

struct ESPNCompetition: Decodable {
    let competitors: [ESPNCompetitor]
}

struct ESPNCompetitor: Decodable {
    let homeAway: String
    let score: String?
    let team: ESPNTeam
}

struct ESPNTeam: Decodable {
    let id: String
    let abbreviation: String?
    let logos: [ESPNLogo]?
}

struct ESPNLogo: Decodable {
    let href: String
}

extension ESPNScoreboardResponse {
    func toMatches(competitionName: String, competitionSlug: String) -> [Match] {
        events.compactMap { event -> Match? in
            guard let competition = event.competitions.first,
                  let home = competition.competitors.first(where: { $0.homeAway == "home" }),
                  let away = competition.competitors.first(where: { $0.homeAway == "away" }) else {
                return nil
            }

            func team(from competitor: ESPNCompetitor) -> Team {
                let crest = competitor.team.logos?.first.flatMap { URL(string: $0.href) }
                return Team(
                    id: competitor.team.id,
                    shortName: competitor.team.abbreviation ?? "?",
                    crestURL: crest
                )
            }

            let status: MatchStatus
            switch event.status.type.state {
            case "in":
                let minute = Int(event.status.type.shortDetail?.filter(\.isNumber) ?? "") ?? 0
                status = .live(minute: minute)
            case "post":
                status = .finished
            default:
                status = .scheduled(Date())
            }

            return Match(
                id: event.id,
                competitionSlug: competitionSlug,
                competitionName: competitionName,
                homeTeam: team(from: home),
                awayTeam: team(from: away),
                homeScore: Int(home.score ?? "0") ?? 0,
                awayScore: Int(away.score ?? "0") ?? 0,
                status: status
            )
        }
    }
}
