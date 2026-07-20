import Foundation

protocol ESPNClientProtocol {
    func fetchMatches(competitionSlug: String, competitionName: String) async throws -> [Match]
    func fetchStats(competitionSlug: String, eventID: String) async throws -> MatchStats
}

final class ESPNClient: ESPNClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchMatches(competitionSlug: String, competitionName: String) async throws -> [Match] {
        let url = ESPNEndpoints.scoreboardURL(slug: competitionSlug)
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: data)
        return decoded.toMatches(competitionName: competitionName, competitionSlug: competitionSlug)
    }

    func fetchStats(competitionSlug: String, eventID: String) async throws -> MatchStats {
        let url = ESPNEndpoints.summaryURL(slug: competitionSlug, eventID: eventID)
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(ESPNSummaryResponse.self, from: data)
        return decoded.toMatchStats()
    }
}
