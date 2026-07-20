# FootballNotch — Project Journal

A running log of what was built, what broke, and why, for future reference.
Newest entries at the bottom of each day's section.

---

## 2026-07-19 — Initial build (Tasks 1–14)

Built the whole app from a written implementation plan
(`docs/superpowers/plans/2026-07-19-football-notch-companion.md`), task by
task, each verified with tests before moving on:

1. **Project scaffolding + NotchGeometry** — Xcode project via xcodegen;
   `NotchGeometry.notchFrame(for:)` computes the notch's on-screen rect from
   `NSScreen.safeAreaInsets`.
2. **NotchPanel** — borderless `NSPanel` overlay. Needed several follow-up
   fixes the same day: the SwiftUI content was collapsing the window to a
   tiny size (fixed by disabling `NSHostingView` auto-sizing), and content
   centered directly on the notch was invisible (the cutout has zero real
   screen pixels — it's a physical camera hole, not just a software inset).
3. **Domain models** — `Team`, `Match`, `MatchStatus`, `MatchStats`.
4. **ESPN endpoints + tolerant decoding** — `ESPNEndpoints`,
   `ESPNScoreboardResponse`, `ESPNSummaryResponse`, all tolerant of missing
   fields (ESPN's API is unofficial/undocumented).
5. **ESPNClient** — async `URLSession`-based networking.
6. **GoalDiffDetector** — pure score-diff logic, defensive against score
   *decreases* (ESPN corrections) never firing a false goal alert.
7. **FollowedMatchStore** — `UserDefaults`-backed persistence for the
   followed match ID and supported team ID.
8. **MatchPollingService** — ties networking + goal detection + persistence
   together; polls all tracked competitions, publishes live matches.
9. **CrestCache + CrestImageView** — disk+memory image cache with
   initials-fallback rendering.
10. **AppState + CompactPillView** — the `NotchDisplayMode` state machine
    (`hidden` / `compactPill` / `hoverExpanded` / `goalAlert`).
11. **HoverExpandedView, MatchPickerRow, StatsView** — the hover panel.
12. **GoalSoundPlayer + GoalAlertView** — goal celebration UI.
13. **Wired everything together** in `FootballNotchApp`/`AppDelegate`.
14. **Distribution scaffolding** — `Distribution/build_release.sh` and a
    Homebrew Cask formula template. Left deliberately incomplete: signing
    needs the user's own Apple Developer ID, and `ExportOptions.plist` needs
    their Team ID — neither can be fabricated.

Also: moved the whole project from a nested `.claude/worktrees/...` git
worktree into `Dynamic-Island/FootballNotch/` directly, at the user's
request, so nothing code-related sits under `.claude/` or `docs/`.

No git commits were made at any point (explicit standing instruction) —
everything was left as uncommitted working-tree changes.

---

## 2026-07-20, early morning (01:00–02:30) — Interaction bugs

A separate session fixed a cluster of real-device bugs reported after first
running the app:

- **Hover stopped working after the first expand/collapse cycle.**
  Root cause: `NSTrackingArea`'s `mouseEntered`/`mouseExited` delivery is
  unreliable on a borderless, non-activating, `.screenSaver`-level panel —
  it silently stops firing after the window is resized once. Fixed by
  replacing it entirely with a 20ms polling timer that checks
  `NSEvent.mouseLocation` against the panel's frame.
- **Clicks on match rows did nothing.** A non-activating accessory-app panel
  never becomes key on its own, so AppKit was swallowing the first click just
  to focus the window. Fixed with a custom `NSHostingView` subclass
  overriding `acceptsFirstMouse(for:)`.
- **Resize was janky.** Replaced ad-hoc resizing with explicit
  `NSAnimationContext` timing.
- **Content rendered partly behind the camera.** The original design let the
  panel "peek" into the notch cutout; moved the panel to sit fully below the
  cutout instead (later revisited — see below).

---

## 2026-07-20, midday–afternoon — Geometry rework and missing features

### Centering, positioning, and physical sizing

- **Root cause of "notch not centered":** `NSScreen.main` is whichever
  screen currently owns the menu bar/key window — with an external monitor
  connected, that's often *not* the built-in display at all. Added
  `NotchGeometry.notchedScreen()` to explicitly find the screen with a real
  notch (`safeAreaInsets.top > 0`).
- **Physical cm-accurate sizing:** the user gave exact measurements (pill
  starts 1cm below the screen top, expands to 4cm tall × notch-width+4cm on
  hover). Implemented `NotchGeometry.points(fromCM:on:)`, converting via the
  display's real physical size (`CGDisplayScreenSize`) rather than fixed
  point values — so it's correct on any Mac, not tuned to one specific
  screen.
- **Replaced content-measured resizing** (a SwiftUI `GeometryReader` +
  `PreferenceKey` feedback loop) **with fixed target frames** driven
  directly by app state — simpler, and removed a source of the earlier
  flicker/hover-breaking bugs.
- Then the "1cm below the screen top" offset turned out to visually put the
  pill *below* the real notch instead of at it — the true notch cutout
  itself starts flush at the screen's physical top edge, so the offset was
  corrected to `0` (flush with `screenFrame.maxY`) rather than an estimated
  physical distance.
- **Idle vs. tracking size:** originally one "resting" frame was used for
  both the idle (no match) and compact (tracking a match) states, widened to
  90pt-left/55pt-right to fit "HOME vs AWAY · score" text. The user wanted
  the *idle* state to stay small and tight to the camera, like the original
  design — split into three explicit `NotchPanel.VisualState` cases:
  `.idle` (small, ~20pt margins), `.compact` (wide, for team names + score),
  `.expanded` (the 4cm hover box).
- **"Pick a match" text hidden behind the camera:** the expanded panel's top
  edge is flush with the real notch row, so content starting right at the
  top rendered under the dead-pixel zone. Fixed with an explicit top inset
  in `HoverExpandedView` equal to the cutout's height.

### The "sticking to whichever app is active" bug

Reported repeatedly: the panel would vanish when switching apps/spaces and
seemed to "belong" to whichever app was frontmost, instead of staying
independently on screen. Several rounds of `collectionBehavior` tuning
(`.transient` was tried and reverted — it excludes a window from
Spaces/Mission Control's window set entirely, causing exactly this kind of
vanishing) didn't fully fix it. The actual root cause, found later:

> `NSPanel` (unlike `NSWindow`) defaults `hidesOnDeactivate` to **`true`**.
> For a background/accessory-policy app, "inactive" is the normal state
> almost all the time — so AppKit was auto-hiding the panel constantly.

Fixed with one explicit line: `panel.hidesOnDeactivate = false`.

### Missing features found while reviewing the flow

- **`supportedTeamID` was never actually set anywhere in the UI.** Goal
  celebration vs. "conceded" coloring existed in `GoalAlertView` but had no
  way to ever be populated. Added a "Which team are you supporting?" prompt
  (`SupportTeamPromptView`) shown after picking a match, before it's
  actually followed.
- **Compact pill redesigned:** team initials ("BAR vs RMA") on the left,
  score on the right, deliberately split across the notch's dead zone
  (matches the wider `.compact` panel size above) — replaced the crest-icon
  layout.
- **Goal log:** `MatchPollingService.followedMatchGoalEvents` now tracks a
  simple team-level "who scored" log (e.g. "⚽️ Barcelona — 1-0"), shown in
  the hover panel. Real player names would need new ESPN summary-endpoint
  parsing that doesn't exist yet — flagged as a known gap, not faked.
- **Goal alert animation:** added a spring-based scale/opacity "pop" on
  appear (bigger overshoot for celebrating than conceding).
- **Content cross-fade:** `NotchRootView` previously snapped between
  `IdleIndicatorView`/`CompactPillView`/`HoverExpandedView`/`GoalAlertView`
  instantly while the window frame animated smoothly — now both the frame
  and the SwiftUI content animate together (0.28s easeOut, matching
  `NotchPanel`'s resize timing).
- **Navigation sounds:** added `UISoundPlayer`, using macOS's built-in named
  system sounds (`Tink` for expand/collapse, `Pop` for match selection) —
  no custom audio assets are bundled, same constraint as `GoalSoundPlayer`'s
  goal sounds.

### ESPN data verified against the real live API

Pulled real data from `https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard`
(and a live summary endpoint) to check the decoding assumptions, rather than
trusting the synthetic test fixtures alone:

- Event IDs and scores **are** JSON strings as assumed — decode correctly.
- **Bug found:** team crest images use a single `"logo"` string field in the
  real API, not the `"logos"` array the original `ESPNTeam` model assumed.
  That field simply doesn't exist under that name on this endpoint, so
  crests were silently always falling back to initials (no crash — the
  tolerant decoding "worked as designed," just against the wrong field
  name). Fixed by adding `logo: String?`, preferring it over the `logos`
  array fallback. Added a regression test using the real payload shape.
- **Unverified:** the specific stat field names `MatchStats` looks for
  (`possessionPct`, `totalShots`, `shotsOnTarget`, `fouls`) couldn't be
  checked against real data, since no match with live in-play statistics was
  available at the time. Worth re-checking once possible.

### Housekeeping

- Tightened root `.gitignore` before the first push: added `*.xcresult`,
  `*.xcarchive`, and explicit `.claude/` / `.superpowers/` entries (Claude
  Code's own working files — `.superpowers/` already had a nested
  `.gitignore` doing this, the root entries are belt-and-suspenders).
- No git commits made — still standing instruction.

---

## 2026-07-20, evening — Debug demo mode, real-data verification, polish, and layout bugs

### DemoESPNClient — a debug-only way to see the whole flow without a live match

It's currently the off-season for every tracked competition (confirmed by
hitting the real API — see below), so there was no way to see the
idle → pick-a-match → compact-pill → hover-stats → goal-alert flow working
end-to-end. Added `FootballNotch/Debug/DemoESPNClient.swift`, an
`ESPNClientProtocol` implementation returning canned data instead of real
network calls — wrapped entirely in `#if DEBUG`, so it cannot exist in a
Release build regardless of anything else. Activated only via an
`FN_DEMO_MODE=1` environment variable set in the Xcode scheme (Run >
Arguments > Environment Variables); `AppDelegate.makeClient()` picks between
`DemoESPNClient` and the real `ESPNClient` based on that flag. This exercises
the *real* production pipeline (MatchPollingService, GoalDiffDetector,
AppState, etc.) with fake data — not a separate mock UI.

Iterated on the demo data several times based on testing:
- Two matches from two different competitions (La Liga "BAR vs RMA", Premier
  League "ARS vs COV"), so the picker shows a genuine cross-league choice.
- **Bug found and fixed:** the La Liga demo teams were accidentally given
  Arsenal's and Coventry's real crest URLs (copy-paste mistake reusing the
  same two IDs for both demo matches) — the images loaded fine, just showed
  the wrong team. Fixed by pulling Barcelona/Real Madrid's actual IDs (83/86)
  from ESPN's real `/teams` endpoint and verifying those URLs return HTTP 200.
- Both demo matches now start at minute 0 and tick forward ~1 minute per poll
  (previously jumped 3 minutes per poll, which read as unrealistic) —
  independent counters per match so they don't desync based on which slug
  `ESPNEndpoints.trackedSlugs` happens to poll first.
- **`FollowedMatchStore` persists to real `UserDefaults.standard`** — that's
  correct/intentional for actual use (remembering your followed match across
  restarts), but meant leftover state from a previous demo session carried
  into the next one, skipping straight past the picker. Fixed by having
  `AppDelegate` call `store.clear()` on launch whenever demo mode is active
  (before `AppState` — a `lazy var` — is first touched, since its initial
  mode reads `store.followedMatchID` at construction). Real (non-demo) usage
  is untouched — persistence across launches is still the intended behavior
  there.

### Real ESPN data verified live, twice

Pulled fresh data directly from `https://site.api.espn.com/...` (not just
test fixtures) to answer "are we actually getting ESPN data":
- All 8 tracked competitions (`eng.1`, `esp.1`, `ita.1`, `ger.1`, `fra.1`,
  `uefa.champions`, `uefa.europa`, `fifa.world`) respond correctly with real
  event data right now.
- Confirmed it's genuinely the off-season — every event is `pre` (earliest
  kickoff found: La Liga Aug 15, 2026) or `post`, nothing `in` (live)
  anywhere. The real-time pipeline itself needed no code changes; there's
  just nothing live to show until the season starts.

### Bug: no goal sound ever played

`GoalSoundPlayer` looked for bundled audio files (`goal_celebration.caf` /
`goal_concede.caf`) that were never actually added to the project — the
missing-asset guard silently no-opped every time, so no sound played on any
goal, ever, since Task 12. Replaced with macOS's built-in system sounds:
`"Hero"` (happy, team scores) / `"Basso"` (sad, team concedes) — no custom
audio assets bundled, consistent with `UISoundPlayer`'s approach.

### New: full-time result sound (separate from per-goal sounds)

Added `MatchOutcomeDetector` (pure logic, tested the same way as
`GoalDiffDetector`) and `MatchPollingService.onMatchFinished`, firing once
when the followed match transitions to `.finished`. Wired to the same
Hero/Basso sounds: happy if the supported team won, sad if they lost, silent
on a draw.

### Navigation sounds walked back

Added `UISoundPlayer` sounds for hover-expand/collapse and match selection
earlier in the day; the user asked to remove the hover expand/collapse sound
specifically (`playExpand`/`playCollapse` deleted from `UISoundPlayer`) —
the match-selection `"Pop"` sound stays.

### Visual polish

- Hover panel and goal alert switched from `.circular` to `.continuous`
  corner style (the "squircle" look, matching native macOS/iOS UI) — this
  was the actual technical fix for "not rounded enough."
- Goal alert's celebrate vs. concede entrance animation was two different
  spring curves; unified to one shared spring — only color/text/sound differ
  between outcomes now.
- Compact pill now shows the live match minute (`72'`) next to the score —
  previously the minute was only shown for *other*, unfollowed matches in
  the picker list, not for the match you're actually tracking.

### Two real layout/timing bugs found from user testing

- **Stats not appearing immediately after picking a match.**
  `followedMatchStats` was only ever populated during the next scheduled
  poll cycle (up to `activeInterval` = 12s later). Added an immediate
  fire-and-forget stats fetch inside the new `follow(_ match: Match)`
  overload, alongside optimistically setting `followedMatch` itself
  (same overload, added earlier the same day, for the analogous "compact
  pill has nothing to render immediately after confirming" gap).
- **"Other live matches" not reachable after following a match.** Real
  layout overflow bug, not a data bug: the hover panel's height is fixed at
  exactly 4cm (the user's own spec). The followed-match summary block
  (pill + stats + goal log + divider + label) could exceed that height on
  its own, silently pushing the match-picker list past the bottom of the
  panel with no way to reach it. Fixed by wrapping the *entire* content
  (summary and match list together) in one `ScrollView`, instead of only the
  match list — now reachable by scrolling regardless of how much summary
  content there is. Confirmed this affects real data identically; it's pure
  SwiftUI layout, unrelated to where the data comes from.

### Team-selection prompt alignment

`SupportTeamPromptView` (the "Which team are you supporting?" prompt) used
`VStack(alignment: .leading)` without an explicit `.frame(maxWidth: .infinity)`,
so it hugged its own content width rather than the full panel width, and the
header/button row weren't independently centered — looked visibly
off-center/misaligned. Fixed: explicit `.frame(maxWidth: .infinity)`, centered
internal alignment, and a symmetric invisible mirror of the back-chevron on
the header's right side so the title text is genuinely centered rather than
skewed by the real chevron's width on the left.

### Back navigation added to team-selection prompt

`SupportTeamPromptView` previously had no way out once you tapped a match —
only the two team buttons. Added a `‹` back button that clears `pendingMatch`
and returns to the picker list without confirming anything.

### Cross-device sizing — honesty check

The user asked directly whether sizing is identical across all MacBook
models. Answer, precisely:
- **Notch height** (`safeAreaInsets.top`) and all **cm→points conversions**
  (`CGDisplayScreenSize`-based) are genuinely accurate on any Mac/screen —
  real per-device APIs, no guessing.
- **Notch *width*** (`NotchGeometry.approximateNotchWidth = 200`, a fixed
  point value) is a hardcoded approximation calibrated against the one
  MacBook this was tested on. There's no public AppKit API for notch width
  (only height, via safe area) — unverified whether 200pt is accurate on a
  16" MacBook Pro, 13"/15" MacBook Air, etc. If wrong on another model, the
  effect is imperfect margins around the dead zone, not a crash.
- **Non-notched Macs** (pre-2021 MacBooks, desktops, or a notched MacBook
  driving only an external display): `notchedScreen()` correctly returns
  `nil`, but the fallback path then positions the panel meaninglessly rather
  than just not showing it — a known, not-yet-fixed gap.

### Horizontal offset — added, then reverted

Added a 15pt rightward nudge (`NotchPanel.horizontalOffsetPoints`, applied
identically to all three visual states) per a request to shift the whole
notch right. Immediately reverted per follow-up ("no need to shift... when I
said") — net result, panel is back to exact notch-center, matching the
already-verified-accurate centering math from earlier in the day. Separately
(and kept): the idle emoji's own leading padding was reduced from 8pt to 4pt
to shift *just the emoji* left within the pill — unrelated to the
whole-panel offset, not reverted.

### Housekeeping

- `.gitignore` audited again before a push — confirmed already comprehensive
  (`.DS_Store`, Xcode user state, `.claude/`, `.superpowers/`, `*.xcresult`,
  `*.xcarchive` all correctly excluded); only real project files
  (`UISoundPlayer.swift`, this journal) were ever untracked-and-wanted.
- User committed the project independently at some point
  (`8cff6cb "Dynamic Island Working"`) — outside of/before this session's
  own no-commit-without-asking constraint continuing to apply.

---

## Known open items

- Real player names for goal scorers (needs new ESPN summary parsing).
- `MatchStats` field names (`possessionPct`, `totalShots`, `shotsOnTarget`,
  `fouls`) still unverified against a real live/finished match with actual
  stats present — every live check so far has hit only `pre`/`post` (no
  in-play) matches, off-season.
- Notch **width** (`NotchGeometry.approximateNotchWidth = 200`) is a
  hardcoded value verified only on the one MacBook this was built against —
  unconfirmed on other notched Mac models (16" Pro, 13"/15" Air, etc.).
  Notch height and all cm-based sizing *are* fully accurate everywhere
  (real per-device APIs).
- Non-notched Macs (no built-in notch, or driving only an external display)
  aren't gracefully handled — `NotchPanel` still positions itself using a
  meaningless fallback frame instead of just not showing anything.
- Full "meme" celebration assets — current celebration is a spring
  animation + system sound, not custom artwork/GIFs (nothing fabricated
  without the user sourcing real assets).
- ESPN summary endpoint's richer data (`gameInfo`, `headToHeadGames`,
  `lastFiveGames`, `standings`) isn't parsed/shown anywhere yet — only
  `boxscore` stats are used. Discussed adding facts to the team-selection
  popup; not yet scoped to a specific field the user confirmed they want.
- Task 14 distribution: still needs the user's Apple Developer ID
  (`DEVELOPER_ID_APPLICATION`), a `Distribution/ExportOptions.plist` with
  their Team ID, and a `homebrew-football-notch` GitHub tap repo — all
  account-level actions outside what Claude can do unilaterally.
