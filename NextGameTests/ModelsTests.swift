import Foundation
import Testing

struct ModelsTests {
    let kickoff = Date(timeIntervalSince1970: 1_789_000_000)

    func game(away: Int? = nil, home: Int? = nil) -> Game {
        Game(id: "2026_01_DEN_KC", season: 2026, week: 1, gameType: "REG", kickoff: kickoff,
             awayTeam: "DEN", homeTeam: "KC", awayScore: away, homeScore: home, stadium: nil, spread: nil)
    }

    @Test func teamPerspective() {
        let g = game(away: 10, home: 31)
        #expect(g.involves("KC") && g.involves("DEN") && !g.involves("BUF"))
        #expect(g.isHome("KC") && !g.isHome("DEN"))
        #expect(g.opponent(of: "KC") == "DEN")
        #expect(g.opponent(of: "DEN") == "KC")
        #expect(g.score(of: "KC") == 31)
        #expect(g.score(of: "DEN") == 10)
    }

    @Test func finalNeedsBothScoresAndTheExpectedEnd() {
        let scored = game(away: 10, home: 31)
        #expect(scored.expectedEnd == kickoff + 3.5 * 3600)
        #expect(!scored.isFinal(at: kickoff + 3600))
        #expect(scored.isFinal(at: scored.expectedEnd))
        #expect(!game(away: 10).isFinal(at: kickoff + 5 * 3600))
        #expect(!game().hasScore)
    }

    @Test func thirtyTwoCurrentTeams() {
        #expect(NFLTeams.all.count == 32)
        #expect(NFLTeams.abbrs.contains("LA"))
        #expect(!NFLTeams.abbrs.contains("LAR"))
        #expect(!NFLTeams.abbrs.contains("OAK"))
        #expect(NFLTeams.name(for: "KC") == "Kansas City Chiefs")
        #expect(NFLTeams.name(for: "XYZ") == "XYZ")
    }
}
