import XCTest
@testable import FootballNotch

final class FollowedMatchStoreTests: XCTestCase {
    func test_roundTripsFollowedMatchAndSupportedTeam() {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FollowedMatchStore(defaults: suite)

        store.followedMatchID = "6013"
        store.supportedTeamID = "83"

        XCTAssertEqual(store.followedMatchID, "6013")
        XCTAssertEqual(store.supportedTeamID, "83")
    }

    func test_clear_removesBothValues() {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FollowedMatchStore(defaults: suite)
        store.followedMatchID = "6013"
        store.supportedTeamID = "83"

        store.clear()

        XCTAssertNil(store.followedMatchID)
        XCTAssertNil(store.supportedTeamID)
    }
}
