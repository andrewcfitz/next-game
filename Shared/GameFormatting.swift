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
        if days == 0 || seconds < 12 * 3600 { return "in \(Int(seconds / 3600))h" }
        return "in \(days)d"
    }

    static func statusLine(fetchedAt: Date?, lastError: String?, now: Date, locale: Locale = .current) -> String {
        let age = fetchedAt.map { date -> String in
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = locale
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: now)
        }
        switch (lastError, age) {
        case let (error?, age?): return "\(error) · updated \(age)"
        case let (error?, nil): return error
        case let (nil, age?): return "Updated \(age)"
        case (nil, nil): return "Not updated yet"
        }
    }

    static func inline(_ state: TeamState, team: String, now: Date,
                       calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch state {
        case let .upcoming(next, _, _):
            return "\(team) \(matchup(next, for: team)) · \(compactKickoff(next.kickoff, now: now, calendar: calendar, locale: locale))"
        case let .inProgress(game):
            return game.hasScore ? liveScore(game, for: team) : "\(team) \(matchup(game, for: team)) · In progress"
        case .offseason:
            return "\(team) · Offseason"
        }
    }

    static func rectangularLines(_ state: TeamState, team: String, now: Date,
                                 calendar: Calendar = .current, locale: Locale = .current) -> [String] {
        switch state {
        case let .upcoming(next, last, isBye):
            let when = compactKickoff(next.kickoff, now: now, calendar: calendar, locale: locale)
            let untilKickoff = countdown(to: next.kickoff, now: now, calendar: calendar) + (isBye ? " · bye week" : "")
            return ["\(matchup(next, for: team)) · \(when)", untilKickoff] + [last.map { result($0, for: team) }].compactMap { $0 }
        case let .inProgress(game):
            let header = "\(team) \(matchup(game, for: team))"
            if game.hasScore { return [header, liveScore(game, for: team)] }
            return [header, "In progress", compactKickoff(game.kickoff, now: now, calendar: calendar, locale: locale)]
        case let .offseason(last):
            return [team, "Offseason"] + [last.map { result($0, for: team) }].compactMap { $0 }
        }
    }

    // "Tomorrow" plus a two-digit hour overflows 24 characters on the Lock Screen.
    private static func compactKickoff(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        guard dayDistance(from: now, to: date, calendar: calendar) == 1 else {
            return kickoff(date, now: now, calendar: calendar, locale: locale)
        }
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return "\(date.formatted(style.weekday(.abbreviated))) \(date.formatted(style.hour().minute()))"
    }

    private static func dayDistance(from now: Date, to date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}
