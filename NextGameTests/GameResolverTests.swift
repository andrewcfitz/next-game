import Foundation
import Testing

struct GameResolverTests {
    static let base = try! Date("2026-09-13T17:00:00Z", strategy: .iso8601) // Week 1 Sunday, 1 PM ET
    static let day: TimeInterval = 86400
    static let hour: TimeInterval = 3600

    func game(_ week: Int, _ away: String, _ home: String, dayOffset: Double,
              score: (Int, Int)? = nil, season: Int = 2026) -> Game {
        Game(id: "\(season)_\(week)_\(away)_\(home)", season: season, week: week, gameType: "REG",
             kickoff: Self.base + dayOffset * Self.day, awayTeam: away, homeTeam: home,
             awayScore: score?.0, homeScore: score?.1, stadium: nil, spread: nil)
    }

    @Test func beforeOpenerHasNoLastGame() {
        let w1 = game(1, "DEN", "KC", dayOffset: 1)
        #expect(GameResolver.resolve(team: "KC", games: [w1], now: Self.base) ==
                .upcoming(next: w1, last: nil, isBye: false))
    }

    @Test func betweenGamesShowsLastScore() {
        let w1 = game(1, "DEN", "KC", dayOffset: 0, score: (10, 31))
        let w2 = game(2, "KC", "BUF", dayOffset: 7)
        #expect(GameResolver.resolve(team: "KC", games: [w1, w2], now: Self.base + 2 * Self.day) ==
                .upcoming(next: w2, last: w1, isBye: false))
    }

    @Test func atKickoffIsLive() {
        let w1 = game(1, "DEN", "KC", dayOffset: 0, score: (10, 31))
        let w2 = game(2, "KC", "BUF", dayOffset: 7)
        #expect(GameResolver.resolve(team: "KC", games: [w1, w2], now: w2.kickoff) == .inProgress(w2))
    }

    @Test func liveScoresBeforeExpectedEndStayLive() {
        let w2 = game(2, "KC", "BUF", dayOffset: 7, score: (14, 7))
        #expect(GameResolver.resolve(team: "KC", games: [w2], now: w2.kickoff + 2 * Self.hour) == .inProgress(w2))
    }

    @Test func pastExpectedEndWithoutScoreIsStillLive() {
        let w2 = game(2, "KC", "BUF", dayOffset: 7)
        #expect(GameResolver.resolve(team: "KC", games: [w2], now: w2.kickoff + 5 * Self.hour) == .inProgress(w2))
    }

    @Test func justFinalBecomesLastGame() {
        let w2 = game(2, "KC", "BUF", dayOffset: 7, score: (24, 27))
        let w3 = game(3, "NYJ", "KC", dayOffset: 14)
        #expect(GameResolver.resolve(team: "KC", games: [w2, w3], now: w2.expectedEnd) ==
                .upcoming(next: w3, last: w2, isBye: false))
    }

    @Test func unscoredGameIsDroppedAfterADay() {
        let w1 = game(1, "DEN", "KC", dayOffset: 0, score: (10, 31))
        let w2 = game(2, "KC", "BUF", dayOffset: 7)
        let w3 = game(3, "NYJ", "KC", dayOffset: 14)
        #expect(GameResolver.resolve(team: "KC", games: [w1, w2, w3], now: w2.kickoff + 25 * Self.hour) ==
                .upcoming(next: w3, last: w1, isBye: false))
    }

    @Test func byeTagOnlyDuringTheByeWeek() {
        let w1 = game(1, "DEN", "KC", dayOffset: 0, score: (10, 31))
        let otherW2 = game(2, "DET", "BUF", dayOffset: 4) // Thursday of week 2
        let otherW3 = game(3, "NE", "NYJ", dayOffset: 11) // Thursday of week 3
        let w3 = game(3, "KC", "MIA", dayOffset: 14)
        let games = [w1, otherW2, otherW3, w3]
        func bye(_ offset: Double) -> Bool {
            guard case let .upcoming(_, _, isBye) = GameResolver.resolve(team: "KC", games: games, now: Self.base + offset * Self.day)
            else { Issue.record("expected upcoming"); return false }
            return isBye
        }
        #expect(bye(2) == false)
        #expect(bye(5) == true)
        #expect(bye(12) == false)
    }

    @Test func eliminatedTeamIsInOffseason() {
        let w18 = game(18, "KC", "LV", dayOffset: 0, score: (17, 20))
        let wc = game(19, "BUF", "DEN", dayOffset: 7)
        #expect(GameResolver.resolve(team: "KC", games: [w18, wc], now: Self.base + 8 * Self.day) == .offseason(last: w18))
    }

    @Test func teamWithNoGamesIsOffseasonWithoutLast() {
        #expect(GameResolver.resolve(team: "KC", games: [], now: Self.base) == .offseason(last: nil))
    }

    @Test func previousSeasonLastGameIsHidden() {
        let old = game(22, "KC", "PHI", dayOffset: -200, score: (20, 17), season: 2025)
        let opener = game(1, "DEN", "KC", dayOffset: 1)
        #expect(GameResolver.resolve(team: "KC", games: [old, opener], now: Self.base) ==
                .upcoming(next: opener, last: nil, isBye: false))
    }

    @Test func laterGamesSkipTheFeaturedGame() {
        let w1 = game(1, "DEN", "KC", dayOffset: 0)
        let w2 = game(2, "KC", "BUF", dayOffset: 7)
        let w3 = game(3, "NYJ", "KC", dayOffset: 14)
        let w4 = game(4, "KC", "MIA", dayOffset: 21)
        let all = [w1, w2, w3, w4]
        #expect(GameResolver.laterGames(team: "KC", games: all, now: Self.base - Self.day) == [w2, w3])
        #expect(GameResolver.laterGames(team: "KC", games: all, now: Self.base + Self.hour) == [w2, w3])
        #expect(GameResolver.laterGames(team: "KC", games: all, now: Self.base + 20 * Self.day) == [])
    }

    @Test func timelineDatesAreFutureKickoffsAndEnds() {
        let w1 = game(1, "DEN", "KC", dayOffset: 0, score: (10, 31))
        let w2 = game(2, "KC", "BUF", dayOffset: 7)
        let now = Self.base + 2 * Self.day
        let dates = GameResolver.timelineDates(team: "KC", games: [w1, w2], now: now)
        #expect(dates.first == now)
        #expect(dates.contains(w2.kickoff))
        #expect(dates.contains(w2.expectedEnd))
        #expect(!dates.contains(w1.expectedEnd))
        #expect(dates == dates.sorted())
        #expect(dates.count <= 8)
    }
}
