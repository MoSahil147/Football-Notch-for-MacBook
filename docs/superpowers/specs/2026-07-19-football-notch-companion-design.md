# Football Notch Companion — Design Spec

**Date:** 2026-07-19
**Status:** Approved for planning

## Purpose

A personal, fun macOS app that lets people follow live football scores while
working, using the MacBook notch area the way iPhone's Dynamic Island is used
— glanceable, low-distraction, and out of the way until something worth
noticing happens (a goal). Not a full sports terminal: the goal is "keep half
an eye on the match without breaking focus," so alerts must stay subtle and
short-lived rather than demanding attention.

Target hardware: MacBook Pro/Air models with a physical notch (confirmed dev
target: MacBook Pro M4). No coding experience assumed on the user's side —
Claude will implement, the user will run/test the app visually.

## Competition Scope

- Top 5 European leagues: Premier League, La Liga, Serie A, Bundesliga, Ligue 1
- Champions League and other major club cup competitions (Europa League, etc.)
- Major international tournaments: FIFA World Cup, and similar (e.g. Euros),
  active only during their tournament windows

## Data Source

ESPN's unofficial public soccer API (no key required), e.g.:

- `site.api.espn.com/apis/site/v2/sports/soccer/{league-slug}/scoreboard`
  (slugs: `eng.1`, `esp.1`, `ita.1`, `ger.1`, `fra.1`, `uefa.champions`,
  `uefa.europa`, `fifa.world`, etc.)
- `site.api.espn.com/apis/site/v2/sports/soccer/{league-slug}/summary?event={id}`
  for richer stats (possession, shots, shots on target, fouls, cards) when not
  present on the scoreboard payload.

This API is undocumented and can change without notice. All decoding must be
tolerant of missing/renamed fields — treat parsing failures as "data
unavailable," never as a crash.

## Architecture

Three layers, all native Swift/SwiftUI, packaged as a menu-bar-only app
(`LSUIElement`, no Dock icon):

1. **NotchWindow layer** — a borderless, transparent, always-on-top `NSPanel`
   positioned over/around the physical notch using `NSScreen` safe-area /
   auxiliary-area APIs to find exact notch bounds on the running Mac. This
   recreates the Dynamic-Island visual effect since macOS has no public API
   for it (same technique used by existing open-source notch apps).
2. **Data layer** — a polling service hitting the ESPN endpoints above,
   decoding into internal match models, publishing updates via
   `ObservableObject`/`@Published` state.
3. **UI layer** — SwiftUI views for each visual state, rendered inside the
   one NotchWindow, driven by an app-level state machine.

## UI States & Components

- **Compact Pill** (default while following a match, not hovering): both
  team crests flush against the notch sides with the score between them,
  e.g. `BAR 2-1 RMA`. When no match is being followed, the pill is hidden and
  the notch looks stock.
- **Hover-Expanded Panel** (cursor enters the notch area):
  - If multiple tracked competitions have overlapping live matches, shows a
    scrollable picker (league badge, teams, score, minute).
  - If a match is already selected, shows live stats (possession, shots,
    shots on target, fouls, cards) and a "switch match" control.
- **Match/Team Picker**: on first selecting a live match, a lightweight
  one-time prompt asks which side the user supports — used only to decide
  celebration vs. concede tone for alerts.
- **Goal Alert** (event-driven): notch expands to a moderate size (never
  full-screen) showing the scorer and a short celebratory animation/sound for
  the supported team, or a duller/quieter animation for a conceded goal, then
  auto-collapses back to the compact pill after a few seconds.

## Data Flow / Goal Detection

- **Polling cadence**: ~30–45s for idle/background competitions, ~10–15s for
  the actively-followed match, to catch goals quickly without hammering an
  unofficial API.
- **Goal detection**: diff each poll's score against the last known score per
  match; a change triggers the goal-alert state, with the scoring side
  inferred from which side's score increased. Simpler and more robust than
  parsing ESPN's play-by-play/event feed.
- **Crests**: team logo URLs from the ESPN payload, cached to disk so they
  aren't re-fetched every poll; fallback to team initials (e.g. "BAR",
  "ENG") if a crest fails to load.

## Error Handling

- Network failures, endpoint schema drift, or a match ending mid-session all
  fall back to "last known good state" in the compact pill — no crash, no
  intrusive error UI — and quietly retry on the next poll.

## Testing Approach

Since the user won't be reading logs or writing code, verification is
visual:

- A SwiftUI preview harness with mocked match data (mocked goals, mocked
  overlapping live matches) to verify pill/hover/alert states without
  waiting for a real live match.
- After each implementation phase, run the app and demonstrate the working
  state before moving to the next phase.

## Distribution

The app should be installable via a custom Homebrew tap, the way tools like
`brew install f/textream/textream` or `brew install --cask codexbar` work —
so end users just run `brew install <user>/<tap>/<app-name>` (or `--cask`)
without needing Xcode. This means: a signed/notarized `.app` bundle published
as a GitHub release artifact, plus a small tap repo (or `homebrew-<name>`
repo) containing the Cask/formula that points at it. This is a later-phase
concern (after the app itself works), but the build should produce a
distributable `.app` rather than assuming Xcode-only runs.

## Explicitly Out of Scope (for now)

- Leagues/competitions beyond the top 5 + Champions League/major cups +
  major international tournaments.
- Any paid/official football data API — revisit only if ESPN's unofficial
  API becomes unreliable.
- Full sports-terminal features (league tables, transfer news, fixtures
  beyond live/upcoming-today).
