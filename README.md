# Next Game

A macOS menu bar app and desktop widget, plus an iPhone app with Home Screen and Lock Screen widgets, that follow NFL teams. Add a widget, pick a team, and it shows the next game in your time zone plus the last game's score until the next kickoff.

Data comes from [nflverse](https://github.com/nflverse/nfldata) (`games.csv` and `teams_colors_logos.csv`). No API key.

## Development

`project.yml` is the source of truth; `NextGame.xcodeproj` is generated and gitignored.

1. Run `mise install`, then `Scripts/generate.sh` (any Fastlane lane does this too) and open `NextGame.xcodeproj` (macOS 15+, Xcode 16+).
2. The signing team (`8353VT99LA`) is set per target in `project.yml`. To use a different one, change it there: regenerating overwrites anything set in Xcode. The Mac targets share the App Group `$(TeamIdentifierPrefix)biz.fitz.NextGame`.
3. Run the **NextGame** scheme, then add the widget: *Edit Widgets > Next Game*, and pick a team in the widget's edit sheet.

Tests: `bundle exec fastlane test`, or ⌘U in Xcode.

## iOS

An iPhone app (iOS 18+) with per-team widgets for the Home Screen and Lock Screen. On iOS the widget does most of the fetching; the app refreshes when opened and from a best-effort background task. It ships through TestFlight.

Run `Scripts/generate.sh` and open `NextGame.xcodeproj`. Two schemes: **NextGame** (macOS app, widget and tests) and **NextGameiOS** (iPhone app and widget).

| | Debug (`Config/Dev.xcconfig`) | Release and TestFlight (`Config/Prod.xcconfig`) |
|---|---|---|
| Bundle ID | `biz.fitz.NextGame.dev` | `biz.fitz.NextGame` |
| App Group | `group.biz.fitz.NextGame.dev` | `group.biz.fitz.NextGame` |
| Name | Next Game Dev | Next Game |

The dev build installs beside the TestFlight one. CI builds the iOS app for the simulator on every push; the TestFlight workflow is run by hand. One-time Apple and secrets setup is in [docs/ios-setup.md](docs/ios-setup.md).

## Layout

| Path | Contents |
|---|---|
| `NextGame/` | App: menu bar extra, settings window, refresh loop |
| `NextGameWidget/` | macOS widget extension |
| `NextGameiOS/` | iPhone app: team screen and background refresh |
| `NextGameiOSWidget/` | iOS widget extension (Home Screen and Lock Screen) |
| `WidgetShared/` | Widget provider and views used by both widget extensions |
| `Config/` | Dev and Prod xcconfigs: iOS bundle IDs, App Groups, display names |
| `project.yml` | XcodeGen spec; generates `NextGame.xcodeproj` |
| `Shared/` | Models, CSV parsing, game state, formatting, networking, cache (compiled into every target) |
| `NextGameTests/` | Swift Testing unit tests |
