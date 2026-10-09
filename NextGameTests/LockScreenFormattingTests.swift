import Foundation
import Testing

struct LockScreenFormattingTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    let locale = Locale(identifier: "en_US")
    let now = try! Date("2026-10-08T14:00:00Z", strategy: .iso8601) // Thursday 10 AM ET

    func plain(_ s: String) -> String { s.replacingOccurrences(of: "\u{202F}", with: " ") }

    func game(_ away: String, _ home: String, kickoff: String, score: (Int, Int)? = nil) -> Game {
        Game(id: "\(away)\(home)", season: 2026, week: 5, gameType: "REG", kickoff: try! Date(kickoff, strategy: .iso8601),
             awayTeam: away, homeTeam: home, awayScore: score?.0, homeScore: score?.1, stadium: nil, spread: nil)
    }

    var next: Game { game("KC", "BUF", kickoff: "2026-10-11T17:00:00Z") } // Sunday 1 PM ET
    var last: Game { game("DEN", "KC", kickoff: "2026-10-04T17:00:00Z", score: (10, 31)) }

    func inline(_ state: TeamState) -> String {
        plain(GameFormatting.inline(state, team: "KC", now: now, calendar: calendar, locale: locale))
    }

    func lines(_ state: TeamState) -> [String] {
        GameFormatting.rectangularLines(state, team: "KC", now: now, calendar: calendar, locale: locale).map(plain)
    }

    @Test func inlineText() {
        #expect(inline(.upcoming(next: next, last: last, isBye: false)) == "KC @ BUF · Sun 1:00 PM")
        #expect(inline(.inProgress(game("KC", "BUF", kickoff: "2026-10-08T13:00:00Z", score: (14, 7)))) == "KC 14, BUF 7")
        #expect(inline(.inProgress(game("KC", "BUF", kickoff: "2026-10-08T13:00:00Z"))) == "KC @ BUF · In progress")
        #expect(inline(.offseason(last: last)) == "KC · Offseason")
    }

    @Test func rectangularUpcoming() {
        #expect(lines(.upcoming(next: next, last: last, isBye: false)) == ["@ BUF · Sun 1:00 PM", "in 3d", "W 31-10 vs DEN"])
        #expect(lines(.upcoming(next: next, last: nil, isBye: true)) == ["@ BUF · Sun 1:00 PM", "in 3d · bye week"])
    }

    @Test func rectangularInProgress() {
        #expect(lines(.inProgress(game("KC", "BUF", kickoff: "2026-10-08T13:00:00Z", score: (14, 7)))) == ["KC @ BUF", "KC 14, BUF 7"])
        #expect(lines(.inProgress(game("KC", "BUF", kickoff: "2026-10-08T13:00:00Z"))) == ["KC @ BUF", "In progress", "Today 9:00 AM"])
    }

    @Test func rectangularOffseason() {
        #expect(lines(.offseason(last: last)) == ["KC", "Offseason", "W 31-10 vs DEN"])
        #expect(lines(.offseason(last: nil)) == ["KC", "Offseason"])
    }

    @Test func linesFitTheLockScreen() {
        let far = game("JAX", "LAC", kickoff: "2026-12-20T21:25:00Z")
        let states: [TeamState] = [
            .upcoming(next: far, last: game("JAX", "WAS", kickoff: "2026-10-04T17:00:00Z", score: (38, 41)), isBye: true),
            .inProgress(game("JAX", "LAC", kickoff: "2026-10-08T13:00:00Z", score: (101, 99))),
            .offseason(last: far),
        ]
        for state in states {
            for line in GameFormatting.rectangularLines(state, team: "JAX", now: now, calendar: calendar, locale: locale) {
                #expect(line.count <= 24, "\(line)")
            }
        }
    }

    @Test func tomorrowIsAbbreviatedToTheWeekday() {
        var pacific = calendar
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let saturday = try! Date("2026-10-10T20:00:00Z", strategy: .iso8601) // Saturday 1 PM PT
        let morning = game("LAC", "KC", kickoff: "2026-10-11T17:00:00Z") // Sunday 10 AM PT
        let noon = game("LAC", "KC", kickoff: "2026-10-11T19:00:00Z") // Sunday 12 PM PT
        func lines(_ g: Game) -> [String] {
            GameFormatting.rectangularLines(.upcoming(next: g, last: nil, isBye: false), team: "KC", now: saturday, calendar: pacific, locale: locale).map(plain)
        }
        #expect(lines(morning)[0] == "vs LAC · Sun 10:00 AM")
        #expect(lines(noon)[0] == "vs LAC · Sun 12:00 PM")
        for g in [morning, noon] {
            let text = plain(GameFormatting.inline(.upcoming(next: g, last: nil, isBye: false), team: "JAX", now: saturday, calendar: pacific, locale: locale))
            #expect(text.count <= 26, "\(text)")
            #expect(lines(g).allSatisfy { $0.count <= 24 })
        }
        let live = GameFormatting.rectangularLines(.inProgress(game("LAC", "KC", kickoff: "2026-10-11T19:00:00Z")), team: "KC", now: saturday, calendar: pacific, locale: locale)
        #expect(live.last.map(plain) == "Sun 12:00 PM")
    }
}
