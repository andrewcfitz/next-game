import Foundation
import Testing

struct GameFormattingTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }()
    let locale = Locale(identifier: "en_US")

    func iso(_ s: String) -> Date { try! Date(s, strategy: .iso8601) }

    func game(away: Int? = nil, home: Int? = nil) -> Game {
        Game(id: "g", season: 2026, week: 1, gameType: "REG", kickoff: iso("2026-09-15T00:15:00Z"),
             awayTeam: "DEN", homeTeam: "KC", awayScore: away, homeScore: home, stadium: nil, spread: nil)
    }

    /// ICU puts a narrow no-break space before AM/PM.
    func plain(_ s: String) -> String { s.replacingOccurrences(of: "\u{202F}", with: " ") }

    @Test func matchupFromEachSide() {
        #expect(GameFormatting.matchup(game(), for: "KC") == "vs DEN")
        #expect(GameFormatting.matchup(game(), for: "DEN") == "@ KC")
    }

    @Test func resultPutsTheTeamFirst() {
        #expect(GameFormatting.result(game(away: 10, home: 31), for: "KC") == "W 31-10 vs DEN")
        #expect(GameFormatting.result(game(away: 10, home: 31), for: "DEN") == "L 10-31 @ KC")
        #expect(GameFormatting.result(game(away: 20, home: 20), for: "KC") == "T 20-20 vs DEN")
        #expect(GameFormatting.result(game(), for: "KC") == "vs DEN")
    }

    @Test func liveScore() {
        #expect(GameFormatting.liveScore(game(away: 7, home: 14), for: "KC") == "KC 14, DEN 7")
        #expect(GameFormatting.liveScore(game(), for: "KC") == "In progress")
    }

    @Test func kickoffTextUsesLocalZone() {
        let kickoff = iso("2026-09-15T00:15:00Z") // 6:15 PM Monday in Denver
        func text(_ now: String) -> String {
            plain(GameFormatting.kickoff(kickoff, now: iso(now), calendar: calendar, locale: locale))
        }
        #expect(text("2026-09-14T15:00:00Z") == "Today 6:15 PM")
        #expect(text("2026-09-13T15:00:00Z") == "Tomorrow 6:15 PM")
        #expect(text("2026-09-10T15:00:00Z") == "Mon 6:15 PM")
        #expect(text("2026-09-01T15:00:00Z") == "Sep 14 6:15 PM")
    }

    @Test func countdown() {
        let kickoff = iso("2026-09-15T00:15:00Z")
        func text(_ now: String) -> String {
            GameFormatting.countdown(to: kickoff, now: iso(now), calendar: calendar)
        }
        #expect(text("2026-09-14T23:30:00Z") == "in 45m")
        #expect(text("2026-09-14T15:00:00Z") == "in 9h")
        #expect(text("2026-09-12T15:00:00Z") == "in 2d")
        #expect(text("2026-09-15T01:00:00Z") == "now")
    }

    @Test func countdownAcrossMidnightUsesHours() {
        let kickoff = iso("2026-09-15T07:00:00Z") // 1:00 AM Denver
        let text = GameFormatting.countdown(to: kickoff, now: iso("2026-09-15T05:00:00Z"), calendar: calendar)
        #expect(text == "in 2h")
    }

    @Test func statusLine() {
        let now = iso("2026-10-08T18:00:00Z")
        let fetched = now - 240
        #expect(GameFormatting.statusLine(fetchedAt: nil, lastError: nil, now: now, locale: locale) == "Not updated yet")
        #expect(GameFormatting.statusLine(fetchedAt: fetched, lastError: nil, now: now, locale: locale) == "Updated 4 minutes ago")
        #expect(GameFormatting.statusLine(fetchedAt: nil, lastError: "HTTP 503", now: now, locale: locale) == "HTTP 503")
        #expect(GameFormatting.statusLine(fetchedAt: fetched, lastError: "HTTP 503", now: now, locale: locale) == "HTTP 503 · updated 4 minutes ago")
    }

    @Test func statusLineNamedRelativeTimes() {
        let now = iso("2026-10-08T18:00:00Z")
        #expect(GameFormatting.statusLine(fetchedAt: now - 2, lastError: nil, now: now, locale: locale) == "Updated now")
        #expect(GameFormatting.statusLine(fetchedAt: now + 1, lastError: nil, now: now, locale: locale) == "Updated now")
        #expect(GameFormatting.statusLine(fetchedAt: now - 26 * 3600, lastError: nil, now: now, locale: locale).contains("yesterday"))
    }
}
