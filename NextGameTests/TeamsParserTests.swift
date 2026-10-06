import Foundation
import Testing

struct TeamsParserTests {
    static let fixture = """
    team_abbr,team_name,team_id,team_nick,team_conf,team_division,team_color,team_color2,team_color3,team_color4,team_logo_wikipedia,team_logo_espn
    KC,Kansas City Chiefs,2310,Chiefs,AFC,AFC West,#E31837,#FFB612,#000000,#e31837,https://example.com/w.png,https://a.espncdn.com/i/teamlogos/nfl/500/kc.png
    LAR,Los Angeles Rams,2510,Rams,NFC,NFC West,#003594,#ffd100,#001532,#af925d,https://example.com/w.png,https://a.espncdn.com/i/teamlogos/nfl/500/lar.png
    OAK,Oakland Raiders,2520,Raiders,AFC,AFC West,#000000,#A5ACAF,#000000,#a5acaf,https://example.com/w.png,https://a.espncdn.com/i/teamlogos/nfl/500/oak.png
    LA,Los Angeles Rams,2510,Rams,NFC,NFC West,#003594,#ffd100,#001532,#af925d,https://example.com/w.png,https://a.espncdn.com/i/teamlogos/nfl/500/lar.png
    """

    @Test func keepsCurrentTeamsSortedByName() throws {
        let teams = try TeamsParser.parse(Data(Self.fixture.utf8))
        #expect(teams.map(\.abbr) == ["KC", "LA"])
        #expect(teams[0] == Team(abbr: "KC", name: "Kansas City Chiefs", primaryColor: "#E31837",
                                 secondaryColor: "#FFB612",
                                 logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/kc.png")))
    }

    @Test func missingColumnThrows() {
        let broken = Self.fixture.replacingOccurrences(of: "team_logo_espn", with: "logo")
        #expect(throws: ParseError.missingColumn("team_logo_espn")) {
            try TeamsParser.parse(Data(broken.utf8))
        }
    }
}
