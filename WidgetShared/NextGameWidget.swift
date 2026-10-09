import SwiftUI
import WidgetKit

struct NextGameWidget: Widget {
    let kind = "NextGameWidget"

    #if os(iOS)
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
    #else
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium]
    #endif

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectTeamIntent.self, provider: Provider()) { entry in
            NextGameWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Next Game")
        .description("Your team's next game and last score.")
        .supportedFamilies(Self.families)
    }
}

struct Entry: TimelineEntry {
    var date: Date
    var team: String?
    var state: TeamState?
    var later: [Game]
    var teams: [String: Team]
    var hasSchedule: Bool
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry { .sample }

    func snapshot(for configuration: SelectTeamIntent, in context: Context) async -> Entry {
        let schedule = SnapshotStore.shared.schedule
        if context.isPreview, schedule == nil || configuration.team == nil { return .sample }
        return entry(team: configuration.team?.id, schedule: schedule, at: .now)
    }

    func timeline(for configuration: SelectTeamIntent, in context: Context) async -> Timeline<Entry> {
        let schedule = await loadSchedule(team: configuration.team?.id)
        let now = Date.now
        let team = configuration.team?.id
        let games = schedule?.games ?? []
        var dates = team.map { GameResolver.timelineDates(team: $0, games: games, now: now) } ?? [now]
        // "Tomorrow" has to become "Today" at midnight even when no game boundary falls there.
        let cal = Calendar.current
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)), !dates.contains(midnight) {
            dates.append(midnight)
            dates.sort()
        }
        let reload: TimelineReloadPolicy
        if schedule == nil {
            reload = .after(now + 15 * 60)
        } else {
            let wait = RefreshPolicy.interval(for: Set([team].compactMap { $0 }), games: games, now: now)
            // WidgetKit throttles reloads below about 15 minutes anyway.
            reload = .after(now + max(wait, 15 * 60))
        }
        return Timeline(entries: dates.map { entry(team: team, schedule: schedule, at: $0) }, policy: reload)
    }

    /// macOS: the app keeps the cache fresh. iOS: the widget is the main fetcher. RefreshPolicy decides which.
    private func loadSchedule(team: String?) async -> ScheduleSnapshot? {
        let store = SnapshotStore.shared
        let cached = store.schedule
        let age = cached.map { Date.now.timeIntervalSince($0.fetchedAt) }
        guard RefreshPolicy.widgetShouldFetch(snapshotAge: age, team: team, games: cached?.games ?? [], now: .now) else {
            return cached
        }
        _ = await ScheduleRefresher().refreshSchedule()
        return store.schedule
    }

    private func entry(team: String?, schedule: ScheduleSnapshot?, at date: Date) -> Entry {
        let teams = Dictionary((SnapshotStore.shared.teams?.teams ?? []).map { ($0.abbr, $0) }, uniquingKeysWith: { a, _ in a })
        guard let team, let schedule else {
            return Entry(date: date, team: team, state: nil, later: [], teams: teams, hasSchedule: schedule != nil)
        }
        return Entry(date: date, team: team,
                     state: GameResolver.resolve(team: team, games: schedule.games, now: date),
                     later: GameResolver.laterGames(team: team, games: schedule.games, now: date),
                     teams: teams, hasSchedule: true)
    }
}

extension Entry {
    static var sample: Entry {
        let now = Date.now
        func game(_ week: Int, _ away: String, _ home: String, days: Double, score: (Int, Int)? = nil) -> Game {
            Game(id: "sample\(week)", season: 2026, week: week, gameType: "REG", kickoff: now + days * 86400,
                 awayTeam: away, homeTeam: home, awayScore: score?.0, homeScore: score?.1, stadium: nil, spread: nil)
        }
        return Entry(date: now, team: "KC",
                     state: .upcoming(next: game(5, "KC", "BUF", days: 3), last: game(4, "DEN", "KC", days: -4, score: (10, 31)), isBye: false),
                     later: [game(6, "NYJ", "KC", days: 10), game(7, "KC", "LV", days: 17)],
                     teams: [:], hasSchedule: true)
    }
}

#Preview(as: .systemSmall) {
    NextGameWidget()
} timeline: {
    Entry.sample
}

#Preview(as: .systemMedium) {
    NextGameWidget()
} timeline: {
    Entry.sample
}
