import Foundation

/// nflverse commits every 10 to 20 minutes, so polling faster than that only costs bandwidth.
enum RefreshPolicy {
    static let normal: TimeInterval = 6 * 3600
    static let gameDay: TimeInterval = 10 * 60
    static let leadTime: TimeInterval = 4 * 3600
    static let widgetStaleAfter: TimeInterval = 12 * 3600
    static let teamsMaxAge: TimeInterval = 7 * 86400
    static let widgetMinimumInterval: TimeInterval = 15 * 60

    /// On macOS the menu bar app is always running and keeps the cache fresh; on iOS the app is usually
    /// suspended, so the widget is the main fetcher.
    #if os(macOS)
    static let appIsTheFetcher = true
    #else
    static let appIsTheFetcher = false
    #endif

    static func widgetShouldFetch(snapshotAge: TimeInterval?, team: String?, games: [Game], now: Date,
                                  appIsTheFetcher: Bool = appIsTheFetcher) -> Bool {
        guard let snapshotAge else { return true }
        if appIsTheFetcher { return snapshotAge >= widgetStaleAfter }
        let teams = Set([team].compactMap { $0 })
        return snapshotAge >= max(widgetMinimumInterval, interval(for: teams, games: games, now: now))
    }

    static func interval(for teams: Set<String>, games: [Game], now: Date) -> TimeInterval {
        let relevant = relevantGames(teams, in: games)
        if relevant.contains(where: { isActive($0, at: now) }) { return gameDay }
        guard let window = relevant.map({ $0.kickoff - leadTime }).filter({ $0 > now }).min() else { return normal }
        return max(gameDay, min(normal, window.timeIntervalSince(now)))
    }

    static func isDue(lastAttempt: Date?, teams: Set<String>, games: [Game], now: Date) -> Bool {
        guard let lastAttempt else { return true }
        let relevant = relevantGames(teams, in: games)
        if relevant.contains(where: { isActive($0, at: now) }) { return now >= lastAttempt + gameDay }
        let nextWindow = relevant.map { $0.kickoff - leadTime }.filter { $0 > lastAttempt }.min()
        return now >= min(lastAttempt + normal, nextWindow ?? .distantFuture)
    }

    /// True when a reload could change what a widget for `teams` shows. Other teams' score updates don't count.
    static func relevantGamesChanged(old: [Game]?, new: [Game]?, teams: Set<String>) -> Bool {
        guard let old, let new, old.first?.season == new.first?.season else { return true }
        return relevantGames(teams, in: old) != relevantGames(teams, in: new)
    }

    private static func relevantGames(_ teams: Set<String>, in games: [Game]) -> [Game] {
        games.filter { teams.contains($0.awayTeam) || teams.contains($0.homeTeam) }
    }

    private static func isActive(_ game: Game, at now: Date) -> Bool {
        now >= game.kickoff - leadTime && !game.isFinal(at: now) && now < game.kickoff + Game.staleAfter
    }
}
