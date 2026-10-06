# Next Game: design

Date: 2026-10-06
Status: approved; implementation via subagent-driven development

## Purpose

A macOS menu bar app with desktop widgets that shows an NFL team's next game and the score of its last one. It is a sibling of `~/workspace/next-up` and borrows its structure, caching model, and release tooling.

Success means: you add a widget, pick a team, and it always shows the right next game in your local time, the last score until the next kickoff, and keeps working offline from cache.

## Scope

In:
- NFL only (regular season and playoffs).
- macOS 15+ only. Menu bar extra plus WidgetKit desktop widgets.
- Any number of widgets; each widget is configured with exactly one team.
- Local caching of schedule, team metadata, and logos.

Out (for now):
- Other leagues, iOS, large widget size, notifications, standings/records, play-by-play.

## Data source

nflverse, the open data behind the `nflreadr` R package. No API key, no quota.

| Data | URL | Refresh |
|---|---|---|
| Schedule and scores | `https://github.com/nflverse/nfldata/raw/master/data/games.csv` | See Refresh policy |
| Team names, colors, logos | `https://github.com/nflverse/nflverse-data/releases/download/teams/teams_colors_logos.csv` | Weekly |

Facts verified on 2026-10-06:
- `games.csv` contains all 272 games of the 2026 regular season; completed games have scores.
- A bot commits updates roughly every 10 to 20 minutes.
- Served with an `ETag` and `cache-control: max-age=300`, so conditional GETs return 304 when unchanged.
- The file covers every season since 1999 (about 2.2 MB). We download it, keep only the current season, and discard the rest.
- `gameday` (YYYY-MM-DD) and `gametime` (HH:MM) are US Eastern local time with no zone field.
- Teams file columns used: `team_abbr, team_name, team_color, team_color2, team_logo_espn`. It has 36 rows including retired franchises (OAK, SD, STL); keep only abbreviations in `NFLTeams`.
- Team abbreviations in both files are nflverse style (`LA` for the Rams, `LV`, `LAC`, `WAS`).
- Relevant columns: `game_id, season, game_type, week, gameday, gametime, away_team, away_score, home_team, home_score, location, spread_line, total_line, roof, stadium`.

Open question to verify on a game night: whether `away_score`/`home_score` are updated during a game or only after it ends. The design handles both (see In progress state).

API-Sports (`v1.american-football.api-sports.io`) was evaluated and rejected: the Free plan cannot query the current season ("Free plans do not have access to this season, try from 2022 to 2024").

## Widget behavior

Each widget instance shows one team, chosen in the widget's edit sheet.

States, resolved from `(team, games, now)`:

- **Upcoming:** next game exists and has not kicked off.
  - Shows opponent logo, "vs OPP" or "@ OPP", kickoff day and time in the user's local time zone, and a countdown ("in 3d", "Tonight 8:15 PM").
  - Shows the last game's final score (for example "W 31-10 vs DEN") **only if the last game is in the same season as the next game**. Before the season opener, no last game is shown.
  - **Bye:** if the team's last and next games skip a week number W, and now is at or after the earliest kickoff of any game in week W (from the snapshot), show a "Bye this week" tag.
- **In progress:** now is between kickoff and the game being final.
  - If scores are present, show the current score; otherwise show "In progress" with the kickoff time.
  - The previous game's score is no longer shown once the next game kicks off.
- **Offseason:** no future game exists for the team (eliminated, or season over and next schedule not yet released).
  - Show the final game's score with an "Offseason" label instead of a countdown.
  - When the new season's schedule appears, the state becomes Upcoming with no last game (season opener rule).

A game is **final** when both scores are present and now is past the expected end. Expected end is kickoff plus 3.5 hours.

Sizes:
- **Small:** the state above.
- **Medium:** the state above plus the next two games after the upcoming one.

## Architecture

The app owns fetching and caching. Widgets read the cached snapshot and only fetch themselves when the snapshot is badly stale.

### Repository layout

`~/workspace/next-game`, bare repo in `.bare/` with a `main/` worktree, matching next-up. Checked-in `NextGame.xcodeproj` with synchronized folders.

```
NextGame/          app target (menu bar, settings, refresh scheduler)
NextGameWidget/    widget extension
Shared/            compiled into app, widget, and tests
NextGameTests/     Swift Testing
fastlane/, Casks/, Scripts/   copied from next-up and renamed
```

Identifiers: bundle `biz.fitz.NextGame`, widget `biz.fitz.NextGame.Widget`, App Group `$(TeamIdentifierPrefix)biz.fitz.NextGame`, team `8353VT99LA`. Both targets sandboxed with outgoing network client.

### Shared components

- **`Models.swift`**
  - `Team`: `abbr`, `name`, `primaryColor`, `secondaryColor`, `logoURL`.
  - `Game`: `id`, `season`, `week`, `gameType`, `kickoff: Date`, `homeTeam`, `awayTeam`, `homeScore: Int?`, `awayScore: Int?`, `stadium`, `spread: Double?`.
  - `TeamState`: `.upcoming(next: Game, last: Game?, isBye: Bool)`, `.inProgress(Game)`, `.offseason(last: Game?)`.
- **`NFLTeams.swift`**: hardcoded list of the 32 team abbreviations and names so the widget team picker works before any fetch.
- **`ScheduleParser.swift`**: parses `games.csv` into `[Game]`, keeping only the season given (current season = the highest `season` value present). Converts Eastern wall time to `Date` using `TimeZone(identifier: "America/New_York")`. Handles quoted fields.
- **`TeamsParser.swift`**: parses the teams CSV into `[Team]`.
- **`GameResolver.swift`**: pure function `resolve(team:games:now:) -> TeamState`, plus `timelineDates(team:games:now:) -> [Date]` returning now, the next kickoff, and the next expected end. All state logic lives here.
- **`NFLVerseClient.swift`**: `URLSession` fetches with `If-None-Match`. Returns `.notModified` or `.updated(data, etag)`. 30 second timeout.
- **`SnapshotStore.swift`**: JSON in the App Group container.
  - `ScheduleSnapshot`: `season`, `games`, `etag`, `fetchedAt`, `lastError: String?`.
  - `TeamsSnapshot`: `teams`, `fetchedAt`.
- **`LogoCache.swift`**: downloads logo PNGs into the App Group container, keyed by team abbreviation, refreshed with the teams snapshot. Widgets read files from disk only. Missing logo falls back to a circular badge with the abbreviation on the team's primary color.

### App

- **Menu bar extra** (`.window` style, no Dock icon):
  - One row per team currently configured in any widget, read via `WidgetCenter.shared.currentConfigurations()`. Each row shows the team's resolved state.
  - Status line: "Updated 4m ago" or the last error, plus a Refresh button.
  - Settings and Quit.
- **Settings window:** launch at login (`SMAppService`).
- **`RefreshScheduler`**:
  - Default interval: 6 hours.
  - Fast interval: 10 minutes, from 4 hours before any configured team's kickoff until that game is final.
  - Also refreshes on launch and on wake.
  - Teams snapshot refreshed when older than 7 days.
  - Calls `WidgetCenter.shared.reloadAllTimelines()` only when the schedule content changed (not on 304).

### Widget

- `AppIntentConfiguration` with a `SelectTeamIntent` whose parameter is a `TeamEntity` (an `AppEntity` backed by `NFLTeams`).
- Timeline entries at each date from `GameResolver.timelineDates`, so state flips at kickoff and at expected end without waiting for a fetch. Reload policy `.after` the next refresh interval.
- If the schedule snapshot is missing or older than 12 hours, the provider fetches and writes the snapshot itself, as next-up does.
- Unconfigured widget shows a placeholder asking to pick a team.

## Data flow

1. App launches or timer fires. `NFLVerseClient` sends a conditional GET for `games.csv`.
2. On 304: update `fetchedAt` and clear `lastError`. No widget reload.
3. On 200: parse current season, write `ScheduleSnapshot`, reload widget timelines.
4. Widgets read the snapshot, call `GameResolver` for their team, and render.

## Error handling

- Network or HTTP failure: keep the last good snapshot, set `lastError`, show it in the menu bar with data age. Widgets keep rendering cached data.
- Parse failure: same as network failure; never overwrite a good snapshot with an empty one.
- No snapshot and no network on first run: widget shows "Waiting for schedule".
- A team with no games in the current season data: Offseason with no last game.

## Testing

Swift Testing, run via Xcode or `bundle exec fastlane test`.

- `ScheduleParser`: trimmed CSV fixture (a few 2025 and 2026 rows, a playoff row, a row with quoted fields, a game with no scores).
- Time conversion: Eastern to local, including the November DST change and a game crossing it.
- `GameResolver`, one test per scenario: before opener, between games, bye week, at kickoff, in progress with and without scores, just final, eliminated, offseason, new schedule released.
- `RefreshScheduler` interval selection given configured teams and now.
- UI is not unit tested.

## Risks

- Live scores may only arrive after games end. Mitigated by the In progress state without a score; verify on Thursday 2026-10-08.
- nflverse file location or columns could change. Parsing is isolated in `ScheduleParser`; failure keeps the last good cache.
- Team logos are fetched at runtime rather than bundled, to avoid shipping NFL trademarks in the app binary.
