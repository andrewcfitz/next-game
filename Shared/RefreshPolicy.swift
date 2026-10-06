import Foundation

/// nflverse commits every 10 to 20 minutes, so polling faster than that only costs bandwidth.
enum RefreshPolicy {
    static let normal: TimeInterval = 6 * 3600
    static let gameDay: TimeInterval = 10 * 60
    static let leadTime: TimeInterval = 4 * 3600
    static let widgetStaleAfter: TimeInterval = 12 * 3600
    static let teamsMaxAge: TimeInterval = 7 * 86400

    static func interval(for teams: Set<String>, games: [Game], now: Date) -> TimeInterval {
        let relevant = games.filter { teams.contains($0.awayTeam) || teams.contains($0.homeTeam) }
        if relevant.contains(where: { isActive($0, at: now) }) { return gameDay }
        guard let window = relevant.map({ $0.kickoff - leadTime }).filter({ $0 > now }).min() else { return normal }
        return max(gameDay, min(normal, window.timeIntervalSince(now)))
    }

    static func isDue(lastAttempt: Date?, teams: Set<String>, games: [Game], now: Date) -> Bool {
        guard let lastAttempt else { return true }
        return now >= lastAttempt + interval(for: teams, games: games, now: now)
    }

    private static func isActive(_ game: Game, at now: Date) -> Bool {
        now >= game.kickoff - leadTime && !game.isFinal(at: now) && now < game.kickoff + Game.staleAfter
    }
}
