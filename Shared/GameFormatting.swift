import Foundation

enum GameFormatting {
    static func matchup(_ game: Game, for team: String) -> String {
        "\(game.isHome(team) ? "vs" : "@") \(game.opponent(of: team))"
    }

    static func result(_ game: Game, for team: String) -> String {
        guard let mine = game.score(of: team), let theirs = game.score(of: game.opponent(of: team)) else {
            return matchup(game, for: team)
        }
        let letter = mine > theirs ? "W" : mine < theirs ? "L" : "T"
        return "\(letter) \(mine)-\(theirs) \(matchup(game, for: team))"
    }

    static func liveScore(_ game: Game, for team: String) -> String {
        let opponent = game.opponent(of: team)
        guard let mine = game.score(of: team), let theirs = game.score(of: opponent) else { return "In progress" }
        return "\(team) \(mine), \(opponent) \(theirs)"
    }

    static func kickoff(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let time = date.formatted(style.hour().minute())
        let days = dayDistance(from: now, to: date, calendar: calendar)
        let day: String
        switch days {
        case 0: day = "Today"
        case 1: day = "Tomorrow"
        case 2..<7: day = date.formatted(style.weekday(.abbreviated))
        default: day = date.formatted(style.month(.abbreviated).day())
        }
        return "\(day) \(time)"
    }

    static func countdown(to date: Date, now: Date, calendar: Calendar = .current) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 0 { return "now" }
        if seconds < 3600 { return "in \(max(1, Int(seconds / 60)))m" }
        let days = dayDistance(from: now, to: date, calendar: calendar)
        if days == 0 { return "in \(Int(seconds / 3600))h" }
        return "in \(days)d"
    }

    private static func dayDistance(from now: Date, to date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}
