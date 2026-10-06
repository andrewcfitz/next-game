import Foundation

enum TeamsParser {
    /// The nflverse file also lists retired franchises (OAK, SD, STL) and aliases (LAR).
    static func parse(_ data: Data) throws -> [Team] {
        guard let text = String(data: data, encoding: .utf8) else { throw ParseError.notUTF8 }
        let rows = CSV.parse(text)
        guard let header = rows.first else { throw ParseError.noRows }
        let columns = CSV.columns(header)
        func index(_ name: String) throws -> Int {
            guard let i = columns[name] else { throw ParseError.missingColumn(name) }
            return i
        }
        let abbr = try index("team_abbr"), name = try index("team_name")
        let color = try index("team_color"), color2 = try index("team_color2"), logo = try index("team_logo_espn")

        let teams = rows.dropFirst()
            .filter { $0.count == header.count && NFLTeams.abbrs.contains($0[abbr]) }
            .map { Team(abbr: $0[abbr], name: $0[name], primaryColor: $0[color],
                        secondaryColor: $0[color2], logoURL: URL(string: $0[logo])) }
        guard !teams.isEmpty else { throw ParseError.noRows }
        return teams.sorted { $0.name < $1.name }
    }
}
