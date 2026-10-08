# Next Game for iOS: design

Date: 2026-10-08
Status: approved in brainstorming, pending spec review
Builds on: `docs/superpowers/specs/2026-10-06-next-game-design.md` (macOS). Everything there still holds for macOS unless this document says otherwise.

## Purpose

Bring Next Game to iPhone: the same per-team widgets (next game in local time, last score until the next kickoff) on the Home Screen and Lock Screen, distributed through TestFlight with a build setup modeled on Earful (`~/workspace/earful/main`).

Success means: a TestFlight build installs on your iPhone, you add a Home Screen or Lock Screen widget, pick a team, and it stays correct through a game day without opening the app. The macOS app keeps working exactly as today.

## Decisions from brainstorming

| Question | Decision |
|---|---|
| Distribution | TestFlight, Earful-style Fastlane. App Store listing later. |
| Repo and runners | Stay at `andrewcfitz/next-game`. GitHub-hosted macOS runners. No OTA PR builds (they need the fitz-biz `fitzy.foo` runner). |
| Widget surfaces | Home Screen small and medium (also StandBy), Lock Screen rectangular and inline. |
| iOS app | One read-only screen of the teams configured in widgets. No settings. |
| Who fetches | The widget extension fetches when the cache is stale; the app refreshes when opened and on best-effort background refresh. macOS unchanged (app fetches). |
| Devices | iPhone only, iOS 18.0+. |

## Scope

In:
- XcodeGen migration of the existing project, keeping macOS behavior identical.
- iOS app target and iOS widget extension target.
- Prod and dev environments.
- Fastlane iOS lanes (bootstrap, certificates, setup, beta) and GitHub Actions for CI and manual release.
- Lock Screen formatters and views.

Out:
- Live Activities and Dynamic Island, iPad, App Store listing and screenshots, OTA PR builds, Lock Screen circular, in-app team following, push notifications.

## Project and build

### XcodeGen

- `project.yml` at the repo root is the source of truth. `NextGame.xcodeproj` becomes generated and gitignored.
- `Scripts/generate.sh` runs `xcodegen generate` (and writes any env xcconfig values it needs). `mise.toml` pins `xcodegen`.
- Targets:

| Target | Platform | Sources | Product |
|---|---|---|---|
| `NextGame` | macOS 15.0 | `NextGame/`, `Shared/` | menu bar app (as today) |
| `NextGameWidgetExtension` | macOS 15.0 | `NextGameWidget/`, `WidgetShared/`, `Shared/` | widget (as today) |
| `NextGameiOS` | iOS 18.0 | `NextGameiOS/`, `Shared/` | iPhone app |
| `NextGameiOSWidgetExtension` | iOS 18.0 | `NextGameiOSWidget/`, `WidgetShared/`, `Shared/` | iPhone widget |
| `NextGameTests` | macOS 15.0 | `NextGameTests/`, `Shared/` | host-less unit tests (as today) |

- Schemes: `NextGame` (macOS app, runs tests), `NextGameiOS` (iOS app).
- `SWIFT_VERSION = 5.0`, team `8353VT99LA`, automatic signing for local Debug builds, manual match signing in CI.
- The migration is accepted only when the existing 65 tests pass and a signed macOS Release build matches today's bundle IDs, App Group entitlement, and Info.plist keys (`LSUIElement`, display name, category `public.app-category.sports`).

### Environments

Two environments, chosen by an xcconfig per configuration (`Config/Prod.xcconfig`, `Config/Dev.xcconfig`); Release uses prod, Debug uses dev.

| | prod | dev |
|---|---|---|
| iOS app bundle ID | `biz.fitz.NextGame` | `biz.fitz.NextGame.dev` |
| iOS widget bundle ID | `biz.fitz.NextGame.Widget` | `biz.fitz.NextGame.dev.Widget` |
| iOS App Group | `group.biz.fitz.NextGame` | `group.biz.fitz.NextGame.dev` |
| Display name | Next Game | Next Game Dev |

macOS keeps `biz.fitz.NextGame`, `biz.fitz.NextGame.Widget`, and `$(TeamIdentifierPrefix)biz.fitz.NextGame` in both configurations, so the installed Mac app and its cache are unaffected. The iOS and macOS apps share bundle IDs, which App Store Connect allows as one multi-platform App ID.

### Fastlane

- Existing lanes (`test`, `release`, `certificates`, `setup`) move under `platform :mac` unchanged in behavior.
- New `platform :ios` lanes, modeled on Earful's Fastfile:
  - `bootstrap`: one-time. `produce` (skip_itc) for the iOS app and widget App IDs in both environments, create both App Groups, enable App Groups on all four IDs, associate the groups. Order: enable the service before associating the group.
  - `appstore_record`: create the App Store Connect record for prod. Name defaults to "Next Game", overridable with `NEXTGAME_ASC_NAME` in case the name is taken.
  - `certificates`: match `development` and `appstore` for the iOS IDs (writes); `setup`: same, read-only.
  - `beta`: `setup_ci` in CI, ASC API key, match appstore read-only, `Scripts/generate.sh`, build number = latest TestFlight build + 1, Release build with manual signing, `upload_to_testflight` (skip waiting for processing, no external testers).
- Match repo: `git@github.com:fitz-biz/earful-certificates.git` (shared, as next-up and the Mac lanes already do).

### GitHub Actions

- `ci.yml` (push to main, PRs), `runs-on: macos-15` or newer hosted image with the needed Xcode:
  - generate the project, run `fastlane mac test`, build `NextGameiOS` for the iOS Simulator unsigned.
- `testflight.yml` (manual only) runs `fastlane ios beta`. The existing `release.yml` (Developer ID, notarize, cask) is unchanged; keeping them separate leaves the Mac release untouched.
- Secrets (same names as next-up and Earful): `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY` (base64 .p8), `APPLE_TEAM_ID`. Adding them to the repo is a manual step for Andrew.

## Shared code changes

- **`AppGroup.id`**: on iOS, read from the `NextGameAppGroup` Info.plist key (set from the environment xcconfig) because `SecTaskCopyValueForEntitlement` is macOS-only. macOS keeps reading the entitlement.
- **`LogoCache.image(for:)`** returns `CGImage?` instead of `NSImage?`; views render `Image(decorative:scale:)`. No AppKit or UIKit import in `Shared/`.
- **Widget staleness** (`RefreshPolicy`):
  - New `static func widgetShouldFetch(snapshotAge: TimeInterval?, team: String?, games: [Game], now: Date, appIsTheFetcher: Bool = appIsTheFetcher) -> Bool`; `appIsTheFetcher` is true on macOS and false on iOS, and is a parameter so both rules are unit tested on macOS.
  - iOS: fetch when there is no snapshot, or when its age is at least `max(15 min, interval(for: [team], games:, now:))`. That is 6 hours normally and 15 minutes around the team's game.
  - macOS: fetch when there is no snapshot or it is older than `widgetStaleAfter` (12 hours), as today.
  - The widget's timeline reload policy stays `.after(now + max(interval, 15 min))`.
- **Lock Screen formatters** in `GameFormatting`, pure and unit tested:
  - `inline(_ state: TeamState, team: String, now: Date) -> String`, e.g. "KC @ BUF · Sun 1:00 PM", "KC 14, BUF 7", "KC · Offseason".
  - `rectangularLines(_ state: TeamState, team: String, now: Date) -> [String]` (up to three), e.g. ["@ BUF · Sun 1:00 PM", "in 3d", "W 31-10 vs DEN"].

## Widget

- `Entry`, `Provider`, and the views move from `NextGameWidget/` to `WidgetShared/`, compiled into both widget extensions. Each extension keeps only its `@main` bundle and its `supportedFamilies`.
- Families: macOS `.systemSmall`, `.systemMedium`; iOS adds `.accessoryRectangular` and `.accessoryInline`.
- Lock Screen views use the formatters above, no logos (`.accessoryInline` is text only; rectangular uses text for legibility in vibrant rendering).
- The provider's fetch decision uses `RefreshPolicy.widgetShouldFetch`.
- Same `SelectTeamIntent` team picker on both platforms.

## iOS app

- One SwiftUI screen:
  - A card per team configured in any widget (`WidgetCenter.shared.currentConfigurations()`), showing the resolved state with the same formatting as the macOS menu rows.
  - Status line: "Updated 4m ago", or the last error with the data age.
  - Pull to refresh.
  - Empty state explaining how to add a widget and pick a team (Home Screen: long-press, Edit, Add Widget; Lock Screen: Customize).
- `IOSAppModel` (`@MainActor @Observable`): refreshes when the scene becomes active, and from a `BGAppRefreshTask` (identifier `biz.fitz.NextGame.refresh`, earliest begin date from `RefreshPolicy.interval`). Uses `ScheduleRefresher`, `LogoCache`, and `RefreshPolicy.relevantGamesChanged` to decide `reloadAllTimelines()`, like the Mac `AppModel`.
- No settings screen.

## Data flow (iOS)

1. Widget timeline request: read the snapshot; if `widgetShouldFetch` says so, run `ScheduleRefresher.refreshSchedule()` (conditional GET), then read the snapshot again.
2. Build entries at `GameResolver.timelineDates` plus the next local midnight.
3. App opened or background task: refresh teams (weekly), logos, schedule; reload widget timelines only when the configured teams' games, the season, or logos changed.

## Error handling

Unchanged from the macOS spec: a failed or garbage download never replaces good data; widgets render the cached snapshot; the app shows the error with the data age.

## Testing

- Existing 65 macOS host-less tests must keep passing through the XcodeGen migration.
- New unit tests: `widgetShouldFetch` (no snapshot, fresh, stale normal, stale near game, macOS 12h rule), `inline` and `rectangularLines` for each `TeamState`, `AppGroup` iOS key lookup via an injectable bundle.
- CI builds the iOS app and widget for the simulator.
- Manual checks (in the plan): widget memory measurement, TestFlight install on a real iPhone, Lock Screen rendering.

## Risks

- **Widget memory.** iOS widget extensions are limited to roughly 30 MB. A cold fetch downloads the 2.2 MB `games.csv` and parses it in the extension. An early plan task measures peak memory of a cold fetch and parse in the iOS Simulator; if it exceeds 20 MB, `ScheduleParser` switches to splitting raw bytes on newlines and only decoding lines with the current season's prefix.
- **App Store Connect name.** "Next Game" may be taken; `NEXTGAME_ASC_NAME` overrides it.
- **XcodeGen migration** could subtly change the macOS build. Gate: tests plus a comparison of the signed macOS app's bundle IDs, entitlements, and Info.plist against the current build.
- **Hosted runner Xcode version** may lag; pin an image that has an Xcode supporting iOS 18 widgets.
