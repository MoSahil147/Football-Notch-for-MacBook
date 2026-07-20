import Foundation

final class FollowedMatchStore {
    private enum Key {
        static let followedMatchID = "followedMatchID"
        static let supportedTeamID = "supportedTeamID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var followedMatchID: String? {
        get { defaults.string(forKey: Key.followedMatchID) }
        set { defaults.set(newValue, forKey: Key.followedMatchID) }
    }

    var supportedTeamID: String? {
        get { defaults.string(forKey: Key.supportedTeamID) }
        set { defaults.set(newValue, forKey: Key.supportedTeamID) }
    }

    func clear() {
        defaults.removeObject(forKey: Key.followedMatchID)
        defaults.removeObject(forKey: Key.supportedTeamID)
    }
}
