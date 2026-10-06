import Foundation
import Testing

struct ScheduleParserTests {
    // Column order differs from nflverse on purpose: the parser must go by header names.
    static let fixture = """
    game_id,season,game_type,week,gameday,weekday,gametime,away_team,away_score,home_team,home_score,location,spread_line,roof,stadium
    2025_22_SEA_NE,2025,SB,22,2026-02-08,Sunday,18:30,SEA,24,NE,20,Neutral,-2.5,outdoors,Levi's Stadium
    2026_01_DEN_KC,2026,REG,1,2026-09-14,Monday,20:15,DEN,10,KC,31,Home,2.5,outdoors,GEHA Field at Arrowhead Stadium
    2026_03_BAL_DAL,2026,REG,3,2026-09-27,Sunday,09:30,BAL,,DAL,,Neutral,,outdoors,"Maracana Stadium, Rio"
    2026_10_KC_BUF,2026,REG,10,2026-11-08,Sunday,,KC,,BUF,,Home,-1.5,outdoors,Highmark Stadium

    """

    func iso(_ s: String) -> Date { try! Date(s, strategy: .iso8601) }

    @Test func keepsOnlyTheLatestSeasonSortedByKickoff() throws {
        let result = try ScheduleParser.parse(Data(Self.fixture.utf8))
        #expect(result.season == 2026)
        #expect(result.games.map(\.id) == ["2026_01_DEN_KC", "2026_03_BAL_DAL", "2026_10_KC_BUF"])
    }

    @Test func readsFields() throws {
        let game = try ScheduleParser.parse(Data(Self.fixture.utf8)).games[0]
        #expect(game == Game(id: "2026_01_DEN_KC", season: 2026, week: 1, gameType: "REG",
                             kickoff: iso("2026-09-15T00:15:00Z"), awayTeam: "DEN", homeTeam: "KC",
                             awayScore: 10, homeScore: 31, stadium: "GEHA Field at Arrowhead Stadium", spread: 2.5))
    }

    @Test func quotedCommaAndMissingScores() throws {
        let game = try ScheduleParser.parse(Data(Self.fixture.utf8)).games[1]
        #expect(game.stadium == "Maracana Stadium, Rio")
        #expect(game.awayScore == nil && game.homeScore == nil && game.spread == nil)
        #expect(game.kickoff == iso("2026-09-27T13:30:00Z"))
    }

    @Test func blankTimeAfterDSTDefaultsToOnePM() throws {
        // DST ends 2026-11-01, so 13:00 EST is 18:00 UTC.
        let game = try ScheduleParser.parse(Data(Self.fixture.utf8)).games[2]
        #expect(game.kickoff == iso("2026-11-08T18:00:00Z"))
    }

    @Test func crlfLineEndings() throws {
        let crlf = Self.fixture.replacingOccurrences(of: "\n", with: "\r\n")
        #expect(try ScheduleParser.parse(Data(crlf.utf8)).games.count == 3)
    }

    @Test func missingColumnThrows() {
        let broken = Self.fixture.replacingOccurrences(of: "home_team,", with: "home,")
        #expect(throws: ParseError.missingColumn("home_team")) {
            try ScheduleParser.parse(Data(broken.utf8))
        }
    }

    @Test func garbageThrows() {
        #expect(throws: ParseError.noRows) {
            try ScheduleParser.parse(Data("<html>rate limited</html>".utf8))
        }
    }

    @Test func csvHandlesDoubledQuotesAndEmbeddedNewlines() {
        let rows = CSV.parse("a,b\n\"say \"\"hi\"\"\",\"two\nlines\"\n")
        #expect(rows == [["a", "b"], ["say \"hi\"", "two\nlines"]])
    }
}
