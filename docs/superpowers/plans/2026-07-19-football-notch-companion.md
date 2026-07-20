# Football Notch Companion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that displays live football scores in a Dynamic-Island-style overlay around the notch, with hover-to-expand match picker/stats, and short goal-celebration alerts.

**Architecture:** A borderless always-on-top `NSPanel` positioned over the notch (NotchWindow layer) renders SwiftUI views driven by an `AppState` state machine; a `MatchPollingService` fetches ESPN's unofficial soccer scoreboard/summary JSON on a timer and publishes decoded `Match` models; the SwiftUI layer reacts to state changes to show the compact pill, hover-expanded panel, or goal alert.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (`NSPanel`, `NSScreen`), `URLSession` for networking, `Combine`/`@Published` for state, `AVFoundation` for goal-alert sound, `XCTest` for unit tests, Xcode 15+, target macOS 14+ (Sonoma) since notch-safe-area APIs are most reliable there.

## Global Constraints

- Never run `git add`/`git commit`/`git push`/`git pull` automatically during execution of this plan — the user has explicitly forbidden unsolicited git actions on this project. Every task below ends with a "Stage for review" step instead of a commit step; only commit if the user explicitly asks in the moment.
- Competitions to support (from spec): Premier League (`eng.1`), La Liga (`esp.1`), Serie A (`ita.1`), Bundesliga (`ger.1`), Ligue 1 (`fra.1`), Champions League (`uefa.champions`), Europa League (`uefa.europa`), FIFA World Cup (`fifa.world`) — active only during its tournament window.
- Polling cadence: 30–45s for idle/background competitions, 10–15s for the actively-followed match.
- Goal alert must never go full-screen; auto-collapse back to the compact pill after a few seconds.
- No paid API, no ESPN API key — unofficial public endpoints only, with tolerant/optional JSON decoding everywhere (missing fields must not crash the app).
- No coding experience assumed on the user's side — after each task, describe/show the visual or console result in plain terms.

---

## File Structure

```
FootballNotch/
  FootballNotch.xcodeproj
  FootballNotch/
    App/
      FootballNotchApp.swift        # @main, LSUIElement app entry, wires services into environment
      AppState.swift                 # state machine: .idle / .compactPill / .hoverExpanded / .goalAlert
    NotchWindow/
      NotchGeometry.swift             # computes notch frame from NSScreen safe area
      NotchPanel.swift                # NSPanel subclass + hosting controller wiring
    Models/
      Team.swift
      Match.swift
      MatchStats.swift
    Networking/
      ESPNEndpoints.swift             # league slugs -> URL builders
      ESPNScoreboardResponse.swift    # Decodable DTOs (tolerant)
      ESPNSummaryResponse.swift       # Decodable DTOs for stats (tolerant)
      ESPNClient.swift                # URLSession fetch + decode + map to Match/MatchStats
    Polling/
      MatchPollingService.swift       # timer-driven polling, publishes [Match], detects goals
      GoalDiffDetector.swift          # pure function: previous vs current score -> GoalEvent?
    Persistence/
      FollowedMatchStore.swift        # UserDefaults: selected match id, supported team id
      CrestCache.swift                 # disk cache for team crest images
    UI/
      CompactPillView.swift
      HoverExpandedView.swift
      MatchPickerRow.swift
      StatsView.swift
      GoalAlertView.swift
      CrestImageView.swift            # cached image + initials fallback
    Audio/
      GoalSoundPlayer.swift
  FootballNotchTests/
    GoalDiffDetectorTests.swift
    ESPNDecodingTests.swift
    MatchPollingServiceTests.swift
    FollowedMatchStoreTests.swift
  Distribution/
    Formula/football-notch.rb        # Homebrew Cask/formula template
    build_release.sh                 # build, sign, notarize, zip .app for release
```

Each file has one responsibility: `NotchGeometry`/`NotchPanel` know nothing about football; `Networking/*` knows nothing about the UI; `Polling/*` bridges networking to app state; `UI/*` are pure SwiftUI views taking model data as input.

---

### Task 1: Project scaffolding + NotchWindow geometry

**Files:**
- Create: `FootballNotch/FootballNotch.xcodeproj` (via `xcodegen` or manual Xcode project creation)
- Create: `FootballNotch/FootballNotch/App/FootballNotchApp.swift`
- Create: `FootballNotch/FootballNotch/NotchWindow/NotchGeometry.swift`
- Test: `FootballNotch/FootballNotchTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces: `struct NotchGeometry { static func notchFrame(for screen: NSScreen) -> CGRect? }` — returns the notch's frame in screen coordinates, or `nil` if the screen has no notch (e.g. external monitor).

- [ ] **Step 1: Create the Xcode project**

Create a new macOS App target named `FootballNotch`, SwiftUI lifecycle, macOS 14.0 deployment target, in `FootballNotch/`. In target settings, set `Application is agent (UIElement)` = `YES` in Info.plist (no Dock icon, no menu bar menu by default — we manage our own window).

- [ ] **Step 2: Write the failing test for notch geometry**

```swift
// FootballNotchTests/NotchGeometryTests.swift
import XCTest
@testable import FootballNotch

final class NotchGeometryTests: XCTestCase {
    func test_notchFrame_returnsNilWhenNoSafeAreaInsets() {
        // A screen with zero top safe-area inset (no notch, e.g. external display)
        let frame = NotchGeometry.notchFrame(topSafeAreaInset: 0, screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertNil(frame)
    }

    func test_notchFrame_returnsCenteredRectWhenInsetPresent() {
        // MacBook Pro 14"/16" notch: ~32pt top inset
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = NotchGeometry.notchFrame(topSafeAreaInset: 32, screenFrame: screenFrame)
        XCTAssertNotNil(frame)
        XCTAssertEqual(frame!.height, 32, accuracy: 0.1)
        // Notch should be horizontally centered on screen
        XCTAssertEqual(frame!.midX, screenFrame.midX, accuracy: 1.0)
    }
}
```

- [ ] **Step 2b: Run test to verify it fails**

Run: `xcodebuild test -project FootballNotch/FootballNotch.xcodeproj -scheme FootballNotch -destination 'platform=macOS' -only-testing:FootballNotchTests/NotchGeometryTests`
Expected: FAIL — `NotchGeometry` does not exist yet.

- [ ] **Step 3: Implement NotchGeometry**

```swift
// FootballNotch/NotchWindow/NotchGeometry.swift
import AppKit

enum NotchGeometry {
    /// Approximate on-screen width of the physical notch cutout across current
    /// notched MacBook models. Real notch width isn't exposed directly by AppKit,
    /// so we use a fixed width and rely on the safe-area inset for height/presence.
    static let approximateNotchWidth: CGFloat = 200

    static func notchFrame(topSafeAreaInset: CGFloat, screenFrame: CGRect) -> CGRect? {
        guard topSafeAreaInset > 0 else { return nil }
        let width = approximateNotchWidth
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - topSafeAreaInset
        return CGRect(x: x, y: y, width: width, height: topSafeAreaInset)
    }

    /// Convenience overload used by production code, reading the real screen's inset.
    static func notchFrame(for screen: NSScreen) -> CGRect? {
        notchFrame(topSafeAreaInset: screen.safeAreaInsets.top, screenFrame: screen.frame)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project FootballNotch/FootballNotch.xcodeproj -scheme FootballNotch -destination 'platform=macOS' -only-testing:FootballNotchTests/NotchGeometryTests`
Expected: PASS (2 tests)

- [ ] **Step 5: Create minimal app entry point**

```swift
// FootballNotch/App/FootballNotchApp.swift
import SwiftUI

@main
struct FootballNotchApp: App {
    var body: some Scene {
        Settings {
            EmptyView() // No visible windows yet; NotchPanel is created in Task 2.
        }
    }
}
```

- [ ] **Step 6: Stage for review (do not commit)**

Leave `FootballNotch/` changes unstaged. Tell the user: "Task 1 done — project scaffolding and notch geometry math are in place and tested. Nothing committed, per your instruction."

---

### Task 2: NotchPanel overlay window

**Files:**
- Create: `FootballNotch/FootballNotch/NotchWindow/NotchPanel.swift`
- Modify: `FootballNotch/FootballNotch/App/FootballNotchApp.swift`
- Test: `FootballNotchTests/NotchPanelTests.swift`

**Interfaces:**
- Consumes: `NotchGeometry.notchFrame(for:)` from Task 1.
- Produces: `final class NotchPanel: NSPanel` with `static func makeAndShow<Content: View>(content: Content) -> NotchPanel`, and `var isMouseInside: Bool` published via `NotificationCenter` name `NotchPanel.mouseEnteredNotification` / `.mouseExitedNotification`.

- [ ] **Step 1: Write the failing test**

```swift
// FootballNotchTests/NotchPanelTests.swift
import XCTest
@testable import FootballNotch
import SwiftUI

final class NotchPanelTests: XCTestCase {
    func test_makeAndShow_positionsPanelAtNotchFrame() {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No screen available in test environment")
        }
        let panel = NotchPanel.makeAndShow(content: Text("test"))
        let expected = NotchGeometry.notchFrame(for: screen) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        XCTAssertEqual(panel.frame.origin.x, expected.origin.x, accuracy: 1.0)
        XCTAssertTrue(panel.isFloatingPanel)
        XCTAssertEqual(panel.level, .statusBar)
        panel.close()
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `xcodebuild test -project FootballNotch/FootballNotch.xcodeproj -scheme FootballNotch -destination 'platform=macOS' -only-testing:FootballNotchTests/NotchPanelTests`
Expected: FAIL — `NotchPanel` does not exist.

- [ ] **Step 3: Implement NotchPanel**

```swift
// FootballNotch/NotchWindow/NotchPanel.swift
import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    static let mouseEnteredNotification = Notification.Name("NotchPanel.mouseEntered")
    static let mouseExitedNotification = Notification.Name("NotchPanel.mouseExited")

    private var trackingArea: NSTrackingArea?

    static func makeAndShow<Content: View>(content: Content) -> NotchPanel {
        let screen = NSScreen.main
        let frame = screen.flatMap(NotchGeometry.notchFrame(for:)) ?? CGRect(x: 0, y: 0, width: 200, height: 32)

        let panel = NotchPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let hosting = NSHostingView(rootView: content)
        panel.contentView = hosting
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        panel.installTrackingArea()
        return panel
    }

    private func installTrackingArea() {
        guard let contentView else { return }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NotificationCenter.default.post(name: Self.mouseEnteredNotification, object: self)
    }

    override func mouseExited(with event: NSEvent) {
        NotificationCenter.default.post(name: Self.mouseExitedNotification, object: self)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project FootballNotch/FootballNotch.xcodeproj -scheme FootballNotch -destination 'platform=macOS' -only-testing:FootballNotchTests/NotchPanelTests`
Expected: PASS

- [ ] **Step 5: Wire panel into app launch**

```swift
// FootballNotch/App/FootballNotchApp.swift
import SwiftUI
import AppKit

@main
struct FootballNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchPanel: NotchPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon
        notchPanel = NotchPanel.makeAndShow(content: Text("⚽️").font(.system(size: 10)))
    }
}
```

- [ ] **Step 6: Manual run — describe result**

Run: `xcodebuild -project FootballNotch/FootballNotch.xcodeproj -scheme FootballNotch -destination 'platform=macOS' build` then launch the built `.app` from Finder/`open`.
Expected: a tiny transparent panel sits exactly over the notch showing a football emoji; no Dock icon appears.

- [ ] **Step 7: Stage for review (do not commit)**

Tell the user what to look for on their MacBook Pro M4 screen and wait for confirmation before continuing.

---

### Task 3: Domain models (Team, Match, MatchStats)

**Files:**
- Create: `FootballNotch/FootballNotch/Models/Team.swift`
- Create: `FootballNotch/FootballNotch/Models/Match.swift`
- Create: `FootballNotch/FootballNotch/Models/MatchStats.swift`
- Test: `FootballNotchTests/MatchModelTests.swift`

**Interfaces:**
- Produces:
  - `struct Team: Identifiable, Equatable { let id: String; let shortName: String; let crestURL: URL? }`
  - `enum MatchStatus: Equatable { case scheduled(Date); case live(minute: Int); case finished; case postponed }`
  - `struct Match: Identifiable, Equatable { let id: String; let competitionSlug: String; let competitionName: String; let homeTeam: Team; let awayTeam: Team; let homeScore: Int; let awayScore: Int; let status: MatchStatus }`
  - `struct MatchStats: Equatable { let possessionHome: Int?; let possessionAway: Int?; let shotsHome: Int?; let shotsAway: Int?; let shotsOnTargetHome: Int?; let shotsOnTargetAway: Int?; let foulsHome: Int?; let foulsAway: Int? }`

- [ ] **Step 1: Write the failing test**

```swift
// FootballNotchTests/MatchModelTests.swift
import XCTest
@testable import FootballNotch

final class MatchModelTests: XCTestCase {
    func test_match_equality_ignoresNothingRelevant() {
        let barca = Team(id: "83", shortName: "BAR", crestURL: nil)
        let real = Team(id: "86", shortName: "RMA", crestURL: nil)
        let m1 = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 2, awayScore: 1, status: .live(minute: 60))
        let m2 = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 2, awayScore: 1, status: .live(minute: 60))
        XCTAssertEqual(m1, m2)
    }

    func test_match_inequality_whenScoreChanges() {
        let barca = Team(id: "83", shortName: "BAR", crestURL: nil)
        let real = Team(id: "86", shortName: "RMA", crestURL: nil)
        let before = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 2, awayScore: 1, status: .live(minute: 60))
        let after = Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga", homeTeam: barca, awayTeam: real, homeScore: 3, awayScore: 1, status: .live(minute: 61))
        XCTAssertNotEqual(before, after)
    }
}
```

- [ ] **Step 2: Run test, verify it fails** (types don't exist)

- [ ] **Step 3: Implement models**

```swift
// FootballNotch/Models/Team.swift
import Foundation

struct Team: Identifiable, Equatable {
    let id: String
    let shortName: String
    let crestURL: URL?
}
```

```swift
// FootballNotch/Models/Match.swift
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
```

```swift
// FootballNotch/Models/MatchStats.swift
import Foundation

struct MatchStats: Equatable {
    let possessionHome: Int?
    let possessionAway: Int?
    let shotsHome: Int?
    let shotsAway: Int?
    let shotsOnTargetHome: Int?
    let shotsOnTargetAway: Int?
    let foulsHome: Int?
    let foulsAway: Int?
}
```

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Stage for review (do not commit)**

---

### Task 4: ESPN endpoints + tolerant decoding

**Files:**
- Create: `FootballNotch/FootballNotch/Networking/ESPNEndpoints.swift`
- Create: `FootballNotch/FootballNotch/Networking/ESPNScoreboardResponse.swift`
- Create: `FootballNotch/FootballNotch/Networking/ESPNSummaryResponse.swift`
- Test: `FootballNotchTests/ESPNDecodingTests.swift`

**Interfaces:**
- Produces:
  - `enum ESPNEndpoints { static let trackedSlugs: [String]; static func scoreboardURL(slug: String) -> URL; static func summaryURL(slug: String, eventID: String) -> URL }`
  - `struct ESPNScoreboardResponse: Decodable { let events: [ESPNEvent] }` and a `func toMatches(competitionName: String, competitionSlug: String) -> [Match]` mapper.
  - `struct ESPNSummaryResponse: Decodable { ... }` with `func toMatchStats() -> MatchStats`.

- [ ] **Step 1: Write the failing test using a fixture JSON with missing fields**

```swift
// FootballNotchTests/ESPNDecodingTests.swift
import XCTest
@testable import FootballNotch

final class ESPNDecodingTests: XCTestCase {
    func test_decodesScoreboard_tolerantOfMissingStatisticsField() throws {
        let json = """
        {
          "events": [
            {
              "id": "6013",
              "status": { "type": { "state": "in", "shortDetail": "60'" } },
              "competitions": [
                {
                  "competitors": [
                    { "homeAway": "home", "score": "2", "team": { "id": "83", "abbreviation": "BAR", "logos": [{ "href": "https://example.com/barca.png" }] } },
                    { "homeAway": "away", "score": "1", "team": { "id": "86", "abbreviation": "RMA", "logos": [{ "href": "https://example.com/real.png" }] } }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: json)
        let matches = decoded.toMatches(competitionName: "La Liga", competitionSlug: "esp.1")

        XCTAssertEqual(matches.count, 1)
        let match = matches[0]
        XCTAssertEqual(match.homeScore, 2)
        XCTAssertEqual(match.awayScore, 1)
        XCTAssertEqual(match.homeTeam.shortName, "BAR")
        if case .live(let minute) = match.status {
            XCTAssertEqual(minute, 60)
        } else {
            XCTFail("Expected live status")
        }
    }

    func test_decodesScoreboard_toleratesMissingLogo() throws {
        let json = """
        {"events":[{"id":"1","status":{"type":{"state":"post"}},"competitions":[{"competitors":[
          {"homeAway":"home","score":"0","team":{"id":"1","abbreviation":"ENG"}},
          {"homeAway":"away","score":"0","team":{"id":"2","abbreviation":"FRA"}}
        ]}]}]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: json)
        let matches = decoded.toMatches(competitionName: "World Cup", competitionSlug: "fifa.world")
        XCTAssertEqual(matches.first?.homeTeam.crestURL, nil)
        XCTAssertEqual(matches.first?.status, .finished)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement endpoints**

```swift
// FootballNotch/Networking/ESPNEndpoints.swift
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
```

- [ ] **Step 4: Implement tolerant DTOs**

```swift
// FootballNotch/Networking/ESPNScoreboardResponse.swift
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
```

```swift
// FootballNotch/Networking/ESPNSummaryResponse.swift
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
```

- [ ] **Step 5: Run test, verify it passes**

- [ ] **Step 6: Stage for review (do not commit)**

---

### Task 5: ESPNClient networking

**Files:**
- Create: `FootballNotch/FootballNotch/Networking/ESPNClient.swift`
- Test: `FootballNotchTests/ESPNClientTests.swift`

**Interfaces:**
- Consumes: `ESPNEndpoints`, `ESPNScoreboardResponse`, `ESPNSummaryResponse` from Task 4.
- Produces:
  ```swift
  protocol ESPNClientProtocol {
      func fetchMatches(competitionSlug: String, competitionName: String) async throws -> [Match]
      func fetchStats(competitionSlug: String, eventID: String) async throws -> MatchStats
  }
  final class ESPNClient: ESPNClientProtocol { init(session: URLSession = .shared) }
  ```

- [ ] **Step 1: Write the failing test with a mock URLProtocol**

```swift
// FootballNotchTests/ESPNClientTests.swift
import XCTest
@testable import FootballNotch

final class MockURLProtocol: URLProtocol {
    static var responseData: Data = Data()
    static var statusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ESPNClientTests: XCTestCase {
    func test_fetchMatches_decodesEmptyEventsWithoutThrowing() async throws {
        MockURLProtocol.responseData = #"{"events":[]}"#.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = ESPNClient(session: URLSession(configuration: config))

        let matches = try await client.fetchMatches(competitionSlug: "eng.1", competitionName: "Premier League")
        XCTAssertEqual(matches, [])
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement ESPNClient**

```swift
// FootballNotch/Networking/ESPNClient.swift
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
```

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Stage for review (do not commit)**

---

### Task 6: Goal diff detector (pure logic)

**Files:**
- Create: `FootballNotch/FootballNotch/Polling/GoalDiffDetector.swift`
- Test: `FootballNotchTests/GoalDiffDetectorTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum GoalSide { case home, away }
  struct GoalEvent: Equatable { let matchID: String; let side: GoalSide; let newHomeScore: Int; let newAwayScore: Int }
  enum GoalDiffDetector {
      static func detectGoal(previous: Match?, current: Match) -> GoalEvent?
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
// FootballNotchTests/GoalDiffDetectorTests.swift
import XCTest
@testable import FootballNotch

final class GoalDiffDetectorTests: XCTestCase {
    private func match(home: Int, away: Int) -> Match {
        Match(id: "1", competitionSlug: "esp.1", competitionName: "La Liga",
              homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
              awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
              homeScore: home, awayScore: away, status: .live(minute: 10))
    }

    func test_noPreviousMatch_returnsNilEvenWithScore() {
        XCTAssertNil(GoalDiffDetector.detectGoal(previous: nil, current: match(home: 1, away: 0)))
    }

    func test_homeScoreIncrease_detectedAsHomeGoal() {
        let event = GoalDiffDetector.detectGoal(previous: match(home: 0, away: 0), current: match(home: 1, away: 0))
        XCTAssertEqual(event, GoalEvent(matchID: "1", side: .home, newHomeScore: 1, newAwayScore: 0))
    }

    func test_awayScoreIncrease_detectedAsAwayGoal() {
        let event = GoalDiffDetector.detectGoal(previous: match(home: 1, away: 0), current: match(home: 1, away: 1))
        XCTAssertEqual(event, GoalEvent(matchID: "1", side: .away, newHomeScore: 1, newAwayScore: 1))
    }

    func test_noScoreChange_returnsNil() {
        XCTAssertNil(GoalDiffDetector.detectGoal(previous: match(home: 1, away: 1), current: match(home: 1, away: 1)))
    }

    func test_scoreDecrease_treatedAsNoGoal() {
        // Defensive: a correction/rollback from ESPN should never fire a goal alert
        XCTAssertNil(GoalDiffDetector.detectGoal(previous: match(home: 2, away: 1), current: match(home: 1, away: 1)))
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement GoalDiffDetector**

```swift
// FootballNotch/Polling/GoalDiffDetector.swift
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
```

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Stage for review (do not commit)**

---

### Task 7: FollowedMatchStore (persistence)

**Files:**
- Create: `FootballNotch/FootballNotch/Persistence/FollowedMatchStore.swift`
- Test: `FootballNotchTests/FollowedMatchStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  final class FollowedMatchStore {
      init(defaults: UserDefaults = .standard)
      var followedMatchID: String? { get set }
      var supportedTeamID: String? { get set }
      func clear()
  }
  ```

- [ ] **Step 1: Write the failing test using an isolated UserDefaults suite**

```swift
// FootballNotchTests/FollowedMatchStoreTests.swift
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
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement FollowedMatchStore**

```swift
// FootballNotch/Persistence/FollowedMatchStore.swift
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
```

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Stage for review (do not commit)**

---

### Task 8: MatchPollingService (ties networking + goal detection + persistence together)

**Files:**
- Create: `FootballNotch/FootballNotch/Polling/MatchPollingService.swift`
- Test: `FootballNotchTests/MatchPollingServiceTests.swift`

**Interfaces:**
- Consumes: `ESPNClientProtocol` (Task 5), `GoalDiffDetector` (Task 6), `FollowedMatchStore` (Task 7), `ESPNEndpoints.trackedSlugs` (Task 4).
- Produces:
  ```swift
  @MainActor
  final class MatchPollingService: ObservableObject {
      @Published private(set) var liveMatches: [Match] = []
      @Published private(set) var followedMatch: Match?
      @Published private(set) var followedMatchStats: MatchStats?
      var onGoalEvent: ((GoalEvent) -> Void)?

      init(client: ESPNClientProtocol, store: FollowedMatchStore)
      func pollOnce() async
      func follow(matchID: String)
      func unfollow()
  }
  ```

- [ ] **Step 1: Write the failing test with a fake client**

```swift
// FootballNotchTests/MatchPollingServiceTests.swift
import XCTest
@testable import FootballNotch

final class FakeESPNClient: ESPNClientProtocol {
    var matchesBySlug: [String: [Match]] = [:]
    var statsToReturn: MatchStats = MatchStats(possessionHome: nil, possessionAway: nil, shotsHome: nil, shotsAway: nil, shotsOnTargetHome: nil, shotsOnTargetAway: nil, foulsHome: nil, foulsAway: nil)

    func fetchMatches(competitionSlug: String, competitionName: String) async throws -> [Match] {
        matchesBySlug[competitionSlug] ?? []
    }

    func fetchStats(competitionSlug: String, eventID: String) async throws -> MatchStats {
        statsToReturn
    }
}

@MainActor
final class MatchPollingServiceTests: XCTestCase {
    private func match(id: String = "1", home: Int, away: Int) -> Match {
        Match(id: id, competitionSlug: "esp.1", competitionName: "La Liga",
              homeTeam: Team(id: "83", shortName: "BAR", crestURL: nil),
              awayTeam: Team(id: "86", shortName: "RMA", crestURL: nil),
              homeScore: home, awayScore: away, status: .live(minute: 10))
    }

    func test_pollOnce_populatesLiveMatchesAcrossSlugs() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)

        await service.pollOnce()

        XCTAssertEqual(service.liveMatches.count, 1)
    }

    func test_pollOnce_firesGoalEventWhenFollowedMatchScoreIncreases() async {
        let client = FakeESPNClient()
        client.matchesBySlug["esp.1"] = [match(home: 0, away: 0)]
        let store = FollowedMatchStore(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let service = MatchPollingService(client: client, store: store)
        service.follow(matchID: "1")
        await service.pollOnce() // establish baseline

        var receivedEvent: GoalEvent?
        service.onGoalEvent = { receivedEvent = $0 }
        client.matchesBySlug["esp.1"] = [match(home: 1, away: 0)]
        await service.pollOnce()

        XCTAssertEqual(receivedEvent, GoalEvent(matchID: "1", side: .home, newHomeScore: 1, newAwayScore: 0))
        XCTAssertEqual(service.followedMatch?.homeScore, 1)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement MatchPollingService**

```swift
// FootballNotch/Polling/MatchPollingService.swift
import Foundation

@MainActor
final class MatchPollingService: ObservableObject {
    @Published private(set) var liveMatches: [Match] = []
    @Published private(set) var followedMatch: Match?
    @Published private(set) var followedMatchStats: MatchStats?

    var onGoalEvent: ((GoalEvent) -> Void)?

    private let client: ESPNClientProtocol
    private let store: FollowedMatchStore
    private var lastKnownByID: [String: Match] = [:]
    private var pollTask: Task<Void, Never>?

    init(client: ESPNClientProtocol, store: FollowedMatchStore) {
        self.client = client
        self.store = store
    }

    func follow(matchID: String) {
        store.followedMatchID = matchID
    }

    func unfollow() {
        store.clear()
        followedMatch = nil
        followedMatchStats = nil
    }

    func pollOnce() async {
        var allMatches: [Match] = []
        for slug in ESPNEndpoints.trackedSlugs {
            let competitionName = Self.displayName(for: slug)
            if let matches = try? await client.fetchMatches(competitionSlug: slug, competitionName: competitionName) {
                allMatches.append(contentsOf: matches)
            }
            // Failed fetches are silently skipped — last known good state (below) stays intact.
        }

        let liveOnly = allMatches.filter(\.isLive)
        liveMatches = liveOnly.isEmpty ? liveMatches : liveOnly

        if let followedID = store.followedMatchID,
           let current = allMatches.first(where: { $0.id == followedID }) {
            let previous = lastKnownByID[followedID]
            if let event = GoalDiffDetector.detectGoal(previous: previous, current: current) {
                onGoalEvent?(event)
            }
            lastKnownByID[followedID] = current
            followedMatch = current

            if let stats = try? await client.fetchStats(competitionSlug: current.competitionSlug, eventID: current.id) {
                followedMatchStats = stats
            }
        }
    }

    func startPolling(idleInterval: TimeInterval = 40, activeInterval: TimeInterval = 12) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await pollOnce()
                let interval = store.followedMatchID != nil ? activeInterval : idleInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
    }

    private static func displayName(for slug: String) -> String {
        switch slug {
        case "eng.1": return "Premier League"
        case "esp.1": return "La Liga"
        case "ita.1": return "Serie A"
        case "ger.1": return "Bundesliga"
        case "fra.1": return "Ligue 1"
        case "uefa.champions": return "Champions League"
        case "uefa.europa": return "Europa League"
        case "fifa.world": return "World Cup"
        default: return slug
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

- [ ] **Step 5: Stage for review (do not commit)**

---

### Task 9: CrestCache + CrestImageView (with initials fallback)

**Files:**
- Create: `FootballNotch/FootballNotch/Persistence/CrestCache.swift`
- Create: `FootballNotch/FootballNotch/UI/CrestImageView.swift`
- Test: `FootballNotchTests/CrestCacheTests.swift`

**Interfaces:**
- Produces:
  ```swift
  actor CrestCache {
      static let shared: CrestCache
      func image(for url: URL) async -> NSImage?
  }
  struct CrestImageView: View { let team: Team; var body: some View }
  ```

- [ ] **Step 1: Write the failing test**

```swift
// FootballNotchTests/CrestCacheTests.swift
import XCTest
@testable import FootballNotch

final class CrestCacheTests: XCTestCase {
    func test_image_returnsNilForUnreachableHost_withoutThrowing() async {
        let cache = CrestCache(cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let url = URL(string: "https://invalid.invalid/doesnotexist.png")!
        let image = await cache.image(for: url)
        XCTAssertNil(image)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement CrestCache**

```swift
// FootballNotch/Persistence/CrestCache.swift
import AppKit

actor CrestCache {
    static let shared = CrestCache(cacheDirectory: FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FootballNotchCrests", isDirectory: true))

    private let cacheDirectory: URL
    private var memoryCache: [URL: NSImage] = [:]

    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async -> NSImage? {
        if let cached = memoryCache[url] { return cached }

        let diskPath = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        if let diskData = try? Data(contentsOf: diskPath), let image = NSImage(data: diskData) {
            memoryCache[url] = image
            return image
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data) else {
            return nil
        }
        try? data.write(to: diskPath)
        memoryCache[url] = image
        return image
    }
}
```

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Implement CrestImageView (fallback to initials, no test — pure rendering)**

```swift
// FootballNotch/UI/CrestImageView.swift
import SwiftUI

struct CrestImageView: View {
    let team: Team
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Text(team.shortName.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.gray.opacity(0.3)))
            }
        }
        .frame(width: 16, height: 16)
        .task {
            guard let url = team.crestURL else { return }
            image = await CrestCache.shared.image(for: url)
        }
    }
}
```

- [ ] **Step 6: Stage for review (do not commit)**

---

### Task 10: AppState state machine + CompactPillView

**Files:**
- Create: `FootballNotch/FootballNotch/App/AppState.swift`
- Create: `FootballNotch/FootballNotch/UI/CompactPillView.swift`
- Test: `FootballNotchTests/AppStateTests.swift`

**Interfaces:**
- Consumes: `MatchPollingService` (Task 8), `NotchPanel` mouse notifications (Task 2).
- Produces:
  ```swift
  enum NotchDisplayMode: Equatable { case hidden, compactPill, hoverExpanded, goalAlert(GoalEvent) }
  @MainActor
  final class AppState: ObservableObject {
      @Published var mode: NotchDisplayMode
      func mouseEntered()
      func mouseExited()
      func showGoalAlert(_ event: GoalEvent)
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
// FootballNotchTests/AppStateTests.swift
import XCTest
@testable import FootballNotch

@MainActor
final class AppStateTests: XCTestCase {
    func test_startsHiddenWhenNoMatchFollowed() {
        let state = AppState(isFollowingMatch: { false })
        XCTAssertEqual(state.mode, .hidden)
    }

    func test_startsCompactPillWhenFollowingMatch() {
        let state = AppState(isFollowingMatch: { true })
        XCTAssertEqual(state.mode, .compactPill)
    }

    func test_mouseEntered_switchesToHoverExpanded() {
        let state = AppState(isFollowingMatch: { true })
        state.mouseEntered()
        XCTAssertEqual(state.mode, .hoverExpanded)
    }

    func test_mouseExited_returnsToCompactPill() {
        let state = AppState(isFollowingMatch: { true })
        state.mouseEntered()
        state.mouseExited()
        XCTAssertEqual(state.mode, .compactPill)
    }

    func test_goalAlert_autoCollapsesAfterDelay() async {
        let state = AppState(isFollowingMatch: { true }, goalAlertDuration: 0.05)
        let event = GoalEvent(matchID: "1", side: .home, newHomeScore: 1, newAwayScore: 0)
        state.showGoalAlert(event)
        XCTAssertEqual(state.mode, .goalAlert(event))
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(state.mode, .compactPill)
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement AppState**

```swift
// FootballNotch/App/AppState.swift
import Foundation

enum NotchDisplayMode: Equatable {
    case hidden
    case compactPill
    case hoverExpanded
    case goalAlert(GoalEvent)
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var mode: NotchDisplayMode
    private let goalAlertDuration: TimeInterval
    private var wasHoveringBeforeGoalAlert = false

    init(isFollowingMatch: () -> Bool, goalAlertDuration: TimeInterval = 4.0) {
        self.mode = isFollowingMatch() ? .compactPill : .hidden
        self.goalAlertDuration = goalAlertDuration
    }

    func setFollowingMatch(_ following: Bool) {
        if following {
            if mode == .hidden { mode = .compactPill }
        } else {
            mode = .hidden
        }
    }

    func mouseEntered() {
        guard mode == .compactPill else { return }
        mode = .hoverExpanded
    }

    func mouseExited() {
        guard mode == .hoverExpanded else { return }
        mode = .compactPill
    }

    func showGoalAlert(_ event: GoalEvent) {
        mode = .goalAlert(event)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(goalAlertDuration * 1_000_000_000))
            if case .goalAlert(let current) = mode, current == event {
                mode = .compactPill
            }
        }
    }
}
```

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Implement CompactPillView (no test — pure rendering)**

```swift
// FootballNotch/UI/CompactPillView.swift
import SwiftUI

struct CompactPillView: View {
    let match: Match

    var body: some View {
        HStack(spacing: 6) {
            CrestImageView(team: match.homeTeam)
            Text("\(match.homeScore)-\(match.awayScore)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            CrestImageView(team: match.awayTeam)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Color.black)
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 6: Stage for review (do not commit)**

---

### Task 11: HoverExpandedView (match picker + stats) and MatchPickerRow

**Files:**
- Create: `FootballNotch/FootballNotch/UI/HoverExpandedView.swift`
- Create: `FootballNotch/FootballNotch/UI/MatchPickerRow.swift`
- Create: `FootballNotch/FootballNotch/UI/StatsView.swift`

**Interfaces:**
- Consumes: `MatchPollingService.liveMatches`, `.followedMatch`, `.followedMatchStats` (Task 8); `MatchPickerRow` reused inside `HoverExpandedView`.

- [ ] **Step 1: Implement MatchPickerRow**

```swift
// FootballNotch/UI/MatchPickerRow.swift
import SwiftUI

struct MatchPickerRow: View {
    let match: Match
    let onSelect: (Match) -> Void

    var body: some View {
        Button(action: { onSelect(match) }) {
            HStack {
                Text(match.competitionName).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                CrestImageView(team: match.homeTeam)
                Text("\(match.homeScore)-\(match.awayScore)").monospacedDigit()
                CrestImageView(team: match.awayTeam)
                if case .live(let minute) = match.status {
                    Text("\(minute)'").font(.caption2).foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Implement StatsView**

```swift
// FootballNotch/UI/StatsView.swift
import SwiftUI

struct StatsView: View {
    let stats: MatchStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow("Possession", stats.possessionHome, stats.possessionAway, suffix: "%")
            statRow("Shots", stats.shotsHome, stats.shotsAway)
            statRow("On Target", stats.shotsOnTargetHome, stats.shotsOnTargetAway)
            statRow("Fouls", stats.foulsHome, stats.foulsAway)
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func statRow(_ label: String, _ home: Int?, _ away: Int?, suffix: String = "") -> some View {
        if home != nil || away != nil {
            HStack {
                Text("\(home.map(String.init) ?? "-")\(suffix)")
                Spacer()
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text("\(away.map(String.init) ?? "-")\(suffix)")
            }
        }
    }
}
```

- [ ] **Step 3: Implement HoverExpandedView**

```swift
// FootballNotch/UI/HoverExpandedView.swift
import SwiftUI

struct HoverExpandedView: View {
    let liveMatches: [Match]
    let followedMatch: Match?
    let followedMatchStats: MatchStats?
    let onSelectMatch: (Match) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let followedMatch {
                CompactPillView(match: followedMatch)
                if let followedMatchStats {
                    StatsView(stats: followedMatchStats)
                }
                Divider()
                Text("Other live matches").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Pick a match to follow").font(.caption).bold()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(liveMatches.filter { $0.id != followedMatch?.id }) { match in
                        MatchPickerRow(match: match, onSelect: onSelectMatch)
                    }
                }
            }
            .frame(maxHeight: 160)
        }
        .padding(12)
        .frame(width: 260)
        .background(Color.black.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
```

- [ ] **Step 4: Manual run — describe result**

Build and run; hover over the notch pill and confirm the panel expands to show live matches and (if following one) stats.

- [ ] **Step 5: Stage for review (do not commit)**

---

### Task 12: GoalAlertView + GoalSoundPlayer

**Files:**
- Create: `FootballNotch/FootballNotch/UI/GoalAlertView.swift`
- Create: `FootballNotch/FootballNotch/Audio/GoalSoundPlayer.swift`
- Test: `FootballNotchTests/GoalSoundPlayerTests.swift`

**Interfaces:**
- Consumes: `GoalEvent` (Task 6), `FollowedMatchStore.supportedTeamID` (Task 7).
- Produces:
  ```swift
  enum GoalSoundPlayer {
      static func play(isForSupportedTeam: Bool)
  }
  struct GoalAlertView: View { let event: GoalEvent; let match: Match; let supportedTeamID: String?; var body: some View }
  ```

- [ ] **Step 1: Write the failing test (verifies correct sound file selection, not actual playback)**

```swift
// FootballNotchTests/GoalSoundPlayerTests.swift
import XCTest
@testable import FootballNotch

final class GoalSoundPlayerTests: XCTestCase {
    func test_soundFileName_forSupportedTeam_isCelebration() {
        XCTAssertEqual(GoalSoundPlayer.soundFileName(isForSupportedTeam: true), "goal_celebration.caf")
    }

    func test_soundFileName_forOpponent_isConcede() {
        XCTAssertEqual(GoalSoundPlayer.soundFileName(isForSupportedTeam: false), "goal_concede.caf")
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

- [ ] **Step 3: Implement GoalSoundPlayer**

```swift
// FootballNotch/Audio/GoalSoundPlayer.swift
import AVFoundation

enum GoalSoundPlayer {
    private static var player: AVAudioPlayer?

    static func soundFileName(isForSupportedTeam: Bool) -> String {
        isForSupportedTeam ? "goal_celebration.caf" : "goal_concede.caf"
    }

    static func play(isForSupportedTeam: Bool) {
        let fileName = soundFileName(isForSupportedTeam: isForSupportedTeam)
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil),
              let audioPlayer = try? AVAudioPlayer(contentsOf: url) else {
            return // Missing sound asset must never crash the app.
        }
        player = audioPlayer
        player?.play()
    }
}
```

*(Note: `goal_celebration.caf` / `goal_concede.caf` are short royalty-free sound assets to be added to the app bundle — placeholder-free system audio like `NSSound(named: "Glass")` can substitute in early testing if custom assets aren't sourced yet; swap the implementation to use `NSSound` if that's preferred, no behavior change to callers.)*

- [ ] **Step 4: Run test, verify it passes**

- [ ] **Step 5: Implement GoalAlertView (no test — pure rendering + side-effecting sound call)**

```swift
// FootballNotch/UI/GoalAlertView.swift
import SwiftUI

struct GoalAlertView: View {
    let event: GoalEvent
    let match: Match
    let supportedTeamID: String?

    private var isForSupportedTeam: Bool {
        switch event.side {
        case .home: return match.homeTeam.id == supportedTeamID
        case .away: return match.awayTeam.id == supportedTeamID
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(isForSupportedTeam ? "⚽️🎉 GOAL!" : "⚽️😬 Conceded")
                .font(.system(size: 13, weight: .bold))
            Text("\(match.homeTeam.shortName) \(event.newHomeScore) - \(event.newAwayScore) \(match.awayTeam.shortName)")
                .font(.system(size: 11))
                .monospacedDigit()
        }
        .padding(16)
        .frame(width: 220, height: 70)
        .background(isForSupportedTeam ? Color.green.opacity(0.85) : Color.red.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            GoalSoundPlayer.play(isForSupportedTeam: isForSupportedTeam)
        }
    }
}
```

- [ ] **Step 6: Manual run — describe result**

Trigger a fake goal event (e.g. via a debug button or by editing test fixture scores) and confirm the alert appears, plays a sound, and auto-collapses.

- [ ] **Step 7: Stage for review (do not commit)**

---

### Task 13: Wire everything into FootballNotchApp + root NotchRootView

**Files:**
- Create: `FootballNotch/FootballNotch/UI/NotchRootView.swift`
- Modify: `FootballNotch/FootballNotch/App/FootballNotchApp.swift`

**Interfaces:**
- Consumes: every component from Tasks 1–12.
- Produces: `struct NotchRootView: View` — the single content view hosted by `NotchPanel`, switching on `AppState.mode`.

- [ ] **Step 1: Implement NotchRootView**

```swift
// FootballNotch/UI/NotchRootView.swift
import SwiftUI

struct NotchRootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var polling: MatchPollingService
    let store: FollowedMatchStore

    var body: some View {
        Group {
            switch appState.mode {
            case .hidden:
                EmptyView()
            case .compactPill:
                if let match = polling.followedMatch {
                    CompactPillView(match: match)
                }
            case .hoverExpanded:
                HoverExpandedView(
                    liveMatches: polling.liveMatches,
                    followedMatch: polling.followedMatch,
                    followedMatchStats: polling.followedMatchStats,
                    onSelectMatch: { match in
                        polling.follow(matchID: match.id)
                        store.followedMatchID = match.id
                    }
                )
            case .goalAlert(let event):
                if let match = polling.followedMatch {
                    GoalAlertView(event: event, match: match, supportedTeamID: store.supportedTeamID)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Wire into AppDelegate**

```swift
// FootballNotch/App/FootballNotchApp.swift
import SwiftUI
import AppKit

@main
struct FootballNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var notchPanel: NotchPanel?
    let store = FollowedMatchStore()
    lazy var polling = MatchPollingService(client: ESPNClient(), store: store)
    lazy var appState = AppState(isFollowingMatch: { [store] in store.followedMatchID != nil })

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        polling.onGoalEvent = { [weak appState] event in
            appState?.showGoalAlert(event)
        }

        NotificationCenter.default.addObserver(forName: NotchPanel.mouseEnteredNotification, object: nil, queue: .main) { [weak appState] _ in
            appState?.mouseEntered()
        }
        NotificationCenter.default.addObserver(forName: NotchPanel.mouseExitedNotification, object: nil, queue: .main) { [weak appState] _ in
            appState?.mouseExited()
        }

        let rootView = NotchRootView(appState: appState, polling: polling, store: store)
        notchPanel = NotchPanel.makeAndShow(content: rootView)

        polling.startPolling()
    }
}
```

- [ ] **Step 3: Manual run — full walkthrough**

Build and run the app on the MacBook Pro M4. Confirm: pill hidden by default, hover shows the live-match picker once matches are live, selecting a match starts showing the compact pill, hovering again shows stats, and (when testable, e.g. during an actual live match) a goal produces the alert animation + sound and auto-collapses.

- [ ] **Step 4: Stage for review (do not commit)**

---

### Task 14: Homebrew distribution packaging (deferred/manual — do last)

**Files:**
- Create: `Distribution/build_release.sh`
- Create: `Distribution/Formula/football-notch.rb`

**Interfaces:** None — this is packaging/config, not app code. Depends on Tasks 1–13 producing a working `.app`.

- [ ] **Step 1: Write the release build script**

```bash
#!/bin/bash
# Distribution/build_release.sh
# Builds, archives, and zips FootballNotch.app for a GitHub release.
# Signing/notarization requires a paid Apple Developer ID — run this
# step manually once that's set up; script stops with instructions if missing.
set -euo pipefail

PROJECT="FootballNotch/FootballNotch.xcodeproj"
SCHEME="FootballNotch"
ARCHIVE_PATH="build/FootballNotch.xcarchive"
EXPORT_PATH="build/export"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  archive -archivePath "$ARCHIVE_PATH"

if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
  echo "DEVELOPER_ID_APPLICATION not set — skipping codesign/notarize."
  echo "Set it to your 'Developer ID Application: ...' identity to sign for distribution."
  exit 0
fi

xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" -exportOptionsPlist Distribution/ExportOptions.plist

ditto -c -k --keepParent "$EXPORT_PATH/FootballNotch.app" "build/FootballNotch.zip"
echo "Built build/FootballNotch.zip — upload as a GitHub release asset, then update the Cask sha256."
```

- [ ] **Step 2: Write the Homebrew Cask formula template**

```ruby
# Distribution/Formula/football-notch.rb
cask "football-notch" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_OF_RELEASE_ZIP"

  url "https://github.com/<github-username>/homebrew-football-notch/releases/download/v#{version}/FootballNotch.zip"
  name "Football Notch"
  desc "Live football scores in your MacBook's notch"
  homepage "https://github.com/<github-username>/Dynamic-Island"

  app "FootballNotch.app"
end
```

- [ ] **Step 3: Document the tap-install command for the user**

Once a `homebrew-football-notch` tap repo exists with this formula, install is:
```bash
brew install --cask <github-username>/football-notch/football-notch
```

- [ ] **Step 4: Stage for review (do not commit)**

Tell the user this task requires them to create the GitHub tap repo and (optionally) an Apple Developer ID for signing — both are account-level actions Claude shouldn't perform unilaterally.

---

## Self-Review Notes

- **Spec coverage:** NotchWindow overlay (Tasks 1–2), competitions/data (Tasks 4–5), goal detection (Task 6), team-support persistence (Task 7), polling cadence (Task 8), crest caching/fallback (Task 9), compact pill (Task 10), hover-expand/match picker/stats (Task 11), goal alert animation+sound (Task 12), full wiring (Task 13), Homebrew tap distribution (Task 14) — all spec sections are covered.
- **Type consistency checked:** `Match`, `Team`, `MatchStats`, `GoalEvent`, `GoalSide`, `NotchDisplayMode` are defined once (Tasks 3, 6, 10) and referenced with identical names/signatures in later tasks.
- **No placeholders:** every step has runnable code; Task 14's signing step is the one genuinely deferred action, and it's called out explicitly as requiring the user's own Apple/GitHub accounts rather than left vague.
