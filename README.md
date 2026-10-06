# Next Game

A macOS menu bar app and desktop widget that follows NFL teams. Add a widget, pick a team, and it shows the next game in your time zone plus the last game's score until the next kickoff.

Data comes from [nflverse](https://github.com/nflverse/nfldata) (`games.csv` and `teams_colors_logos.csv`). No API key.

## Development

1. Open `NextGame.xcodeproj` (macOS 15+, Xcode 16+).
2. For both the **NextGame** and **NextGameWidgetExtension** targets, choose your team under Signing & Capabilities. Both use the App Group `$(TeamIdentifierPrefix)biz.fitz.NextGame`.
3. Run the **NextGame** scheme, then add the widget: *Edit Widgets > Next Game*, and pick a team in the widget's edit sheet.

Tests: `bundle exec fastlane test`, or ⌘U in Xcode.

## Layout

| Path | Contents |
|---|---|
| `NextGame/` | App: menu bar extra, settings window, refresh loop |
| `NextGameWidget/` | Widget extension: timeline provider and views |
| `Shared/` | Models, CSV parsing, game state, formatting, networking, cache (compiled into every target) |
| `NextGameTests/` | Swift Testing unit tests |
