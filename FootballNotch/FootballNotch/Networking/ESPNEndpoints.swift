import Foundation

enum ESPNEndpoints {
    static let trackedSlugs = [
        "eng.1", "esp.1", "ita.1", "ger.1", "fra.1",
        "uefa.champions", "uefa.europa", "fifa.world"
    ]

    private static let base = "https://site.api.espn.com/apis/site/v2/sports/soccer"

    static func scoreboardURL(slug: String) -> URL {
        URL(string: "\(base)/\(slug)/scoreboard")!
    }

    static func summaryURL(slug: String, eventID: String) -> URL {
        URL(string: "\(base)/\(slug)/summary?event=\(eventID)")!
    }
}
