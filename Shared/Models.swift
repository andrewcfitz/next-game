import Foundation

struct Team: Codable, Hashable, Sendable, Identifiable {
    var abbr: String
    var name: String
    /// Hex, e.g. "#E31837".
    var primaryColor: String
    var secondaryColor: String
    var logoURL: URL?

    var id: String { abbr }
}

struct Game: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var season: Int
    var week: Int
    /// nflverse codes: REG, WC, DIV, CON, SB.
    var gameType: String
    var kickoff: Date
    var awayTeam: String
    var homeTeam: String
    var awayScore: Int?
    var homeScore: Int?
    var stadium: String?
    var spread: Double?

    /// nflverse has no end time, so assume a typical broadcast window.
    static let expectedDuration: TimeInterval = 3.5 * 3600
    /// No score this long after kickoff means postponed or bad data; stop treating it as live.
    static let staleAfter: TimeInterval = 24 * 3600

    var expectedEnd: Date { kickoff + Self.expectedDuration }
    var hasScore: Bool { awayScore != nil && homeScore != nil }

    func involves(_ team: String) -> Bool { awayTeam == team || homeTeam == team }
    func isHome(_ team: String) -> Bool { homeTeam == team }
    func opponent(of team: String) -> String { homeTeam == team ? awayTeam : homeTeam }
    func score(of team: String) -> Int? { homeTeam == team ? homeScore : awayScore }

    /// nflverse posts scores only once a game ends (checked on 2026-10-08), so a score after kickoff means final.
    func isFinal(at now: Date) -> Bool { hasScore && now >= kickoff }
}

enum TeamState: Equatable, Sendable {
    case upcoming(next: Game, last: Game?, isBye: Bool)
    case inProgress(Game)
    case offseason(last: Game?)
}
