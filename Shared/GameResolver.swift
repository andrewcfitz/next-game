import Foundation

/// Decides what a team's widget shows at a given moment. Pure, so timelines can ask about future dates.
enum GameResolver {
    static func resolve(team: String, games: [Game], now: Date) -> TeamState {
        let mine = teamGames(team, games)
        if let live = mine.first(where: { isLive($0, at: now) }) {
            return .inProgress(live)
        }
        let last = mine.last { $0.isFinal(at: now) }
        guard let next = mine.first(where: { $0.kickoff > now }) else {
            return .offseason(last: last)
        }
        // Never pair last season's final game with this season's opener.
        let shownLast = last?.season == next.season ? last : nil
        return .upcoming(next: next, last: shownLast, isBye: isBye(team: team, last: shownLast, next: next, games: games, now: now))
    }

    static func isLive(_ game: Game, at now: Date) -> Bool {
        game.kickoff <= now && !game.isFinal(at: now) && now < game.kickoff + Game.staleAfter
    }

    static func laterGames(team: String, games: [Game], now: Date, limit: Int = 2) -> [Game] {
        let mine = teamGames(team, games)
        guard let featured = mine.first(where: { isLive($0, at: now) || $0.kickoff > now }) else { return [] }
        return Array(mine.filter { $0.kickoff > featured.kickoff }.prefix(limit))
    }

    /// Moments the widget's state can change without new data: kickoffs, expected ends, and week starts (bye tag).
    static func timelineDates(team: String, games: [Game], now: Date) -> [Date] {
        var dates: Set<Date> = []
        for game in teamGames(team, games) {
            for date in [game.kickoff, game.expectedEnd, game.kickoff + Game.staleAfter] where date > now {
                dates.insert(date)
            }
        }
        for start in weekStarts(games).values where start > now {
            dates.insert(start)
        }
        return [now] + dates.sorted().prefix(7)
    }

    private static func teamGames(_ team: String, _ games: [Game]) -> [Game] {
        games.filter { $0.involves(team) }.sorted { $0.kickoff < $1.kickoff }
    }

    private struct WeekKey: Hashable {
        var season: Int
        var week: Int
    }

    private static func weekStarts(_ games: [Game]) -> [WeekKey: Date] {
        var starts: [WeekKey: Date] = [:]
        for game in games {
            let key = WeekKey(season: game.season, week: game.week)
            starts[key] = min(starts[key] ?? game.kickoff, game.kickoff)
        }
        return starts
    }

    private static func isBye(team: String, last: Game?, next: Game, games: [Game], now: Date) -> Bool {
        guard let last, next.week > last.week + 1 else { return false }
        let byeWeek = last.week + 1
        if games.contains(where: { $0.involves(team) && $0.season == next.season && $0.week == byeWeek }) { return false }
        let starts = weekStarts(games)
        guard let byeStart = starts[WeekKey(season: next.season, week: byeWeek)] else { return false }
        let nextWeekStart = starts[WeekKey(season: next.season, week: next.week)] ?? next.kickoff
        return now >= byeStart && now < nextWeekStart
    }
}
