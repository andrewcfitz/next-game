import Foundation

enum ScheduleParser {
    static let eastern = TimeZone(identifier: "America/New_York")!
    /// Older seasons and some flexed games have no time yet; Sunday early slot is the best guess.
    static let defaultKickoff = "13:00"

    /// Parses nflverse games.csv, keeping only the latest season in the file.
    static func parse(_ data: Data) throws -> (season: Int, games: [Game]) {
        guard let text = String(data: data, encoding: .utf8) else { throw ParseError.notUTF8 }
        // The file covers every season since 1999; filter lines by the game_id prefix before
        // the full CSV parse to keep memory low in the widget extension.
        let lines = text.split(separator: "\n")
        guard let header = lines.first else { throw ParseError.noRows }
        guard let season = lines.dropFirst().compactMap({ Int($0.prefix(4)) }).max() else { throw ParseError.noRows }
        let prefix = "\(season)_"
        let body = lines.dropFirst().filter { $0.hasPrefix(prefix) }
        let rows = CSV.parse(([header] + body).joined(separator: "\n"))

        let columns = CSV.columns(rows[0])
        func index(_ name: String) throws -> Int {
            guard let i = columns[name] else { throw ParseError.missingColumn(name) }
            return i
        }
        let id = try index("game_id"), seasonCol = try index("season"), type = try index("game_type")
        let week = try index("week"), day = try index("gameday"), time = try index("gametime")
        let away = try index("away_team"), awayScore = try index("away_score")
        let home = try index("home_team"), homeScore = try index("home_score")
        let stadium = try index("stadium"), spread = try index("spread_line")

        var games: [Game] = []
        for row in rows.dropFirst() where row.count == rows[0].count {
            guard let rowSeason = Int(row[seasonCol]), let rowWeek = Int(row[week]),
                  let kickoff = kickoffDate(day: row[day], time: row[time])
            else { continue }
            games.append(Game(
                id: row[id], season: rowSeason, week: rowWeek, gameType: row[type], kickoff: kickoff,
                awayTeam: row[away], homeTeam: row[home],
                awayScore: Int(row[awayScore]), homeScore: Int(row[homeScore]),
                stadium: row[stadium].isEmpty ? nil : row[stadium],
                spread: Double(row[spread])
            ))
        }
        guard !games.isEmpty else { throw ParseError.noRows }
        return (season, games.sorted { $0.kickoff < $1.kickoff })
    }

    static func kickoffDate(day: String, time: String) -> Date? {
        let d = day.split(separator: "-").compactMap { Int($0) }
        let t = (time.isEmpty ? defaultKickoff : time).split(separator: ":").compactMap { Int($0) }
        guard d.count == 3, t.count == 2 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern
        return calendar.date(from: DateComponents(year: d[0], month: d[1], day: d[2], hour: t[0], minute: t[1]))
    }
}
