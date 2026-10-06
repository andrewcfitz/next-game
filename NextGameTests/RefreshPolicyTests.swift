import Foundation
import Testing

struct RefreshPolicyTests {
    let kickoff = Date(timeIntervalSince1970: 1_790_000_000)
    let hour: TimeInterval = 3600

    func game(score: Bool = false) -> Game {
        Game(id: "g", season: 2026, week: 5, gameType: "REG", kickoff: kickoff, awayTeam: "KC", homeTeam: "BUF",
             awayScore: score ? 20 : nil, homeScore: score ? 17 : nil, stadium: nil, spread: nil)
    }

    @Test func noTeamsMeansNormal() {
        #expect(RefreshPolicy.interval(for: [], games: [game()], now: kickoff - hour) == RefreshPolicy.normal)
    }

    @Test func otherTeamsDontCount() {
        #expect(RefreshPolicy.interval(for: ["DEN"], games: [game()], now: kickoff - hour) == RefreshPolicy.normal)
    }

    @Test func gameDayFromFourHoursBefore() {
        #expect(RefreshPolicy.interval(for: ["KC"], games: [game()], now: kickoff - 3 * hour) == RefreshPolicy.gameDay)
        #expect(RefreshPolicy.interval(for: ["KC"], games: [game()], now: kickoff + 2 * hour) == RefreshPolicy.gameDay)
    }

    @Test func wakesWhenTheWindowOpens() {
        #expect(RefreshPolicy.interval(for: ["KC"], games: [game()], now: kickoff - 5 * hour) == hour)
        #expect(RefreshPolicy.interval(for: ["KC"], games: [game()], now: kickoff - 48 * hour) == RefreshPolicy.normal)
    }

    @Test func finalGameStopsFastRefresh() {
        #expect(RefreshPolicy.interval(for: ["KC"], games: [game(score: true)], now: kickoff + 4 * hour) == RefreshPolicy.normal)
    }

    @Test func unscoredGameStopsFastRefreshAfterADay() {
        #expect(RefreshPolicy.interval(for: ["KC"], games: [game()], now: kickoff + 25 * hour) == RefreshPolicy.normal)
    }

    @Test func dueWithoutAPreviousAttempt() {
        #expect(RefreshPolicy.isDue(lastAttempt: nil, teams: [], games: [], now: kickoff))
    }

    @Test func newlyConfiguredTeamMakesRefreshDue() {
        let lastAttempt = kickoff - 2 * hour
        let now = kickoff - 1 * hour
        #expect(!RefreshPolicy.isDue(lastAttempt: lastAttempt, teams: [], games: [game()], now: now))
        #expect(RefreshPolicy.isDue(lastAttempt: lastAttempt, teams: ["KC"], games: [game()], now: now))
    }

    @Test func noMidpointFetchBeforeTheWindow() {
        let window = kickoff - RefreshPolicy.leadTime
        #expect(!RefreshPolicy.isDue(lastAttempt: window - 3 * hour, teams: ["KC"], games: [game()], now: window - 1.5 * hour))
        #expect(RefreshPolicy.isDue(lastAttempt: window - 3 * hour, teams: ["KC"], games: [game()], now: window))
    }

    func other(score: Bool) -> Game {
        Game(id: "o", season: 2026, week: 5, gameType: "REG", kickoff: kickoff, awayTeam: "DEN", homeTeam: "LV",
             awayScore: score ? 3 : nil, homeScore: score ? 0 : nil, stadium: nil, spread: nil)
    }

    @Test func configuredTeamChangeIsRelevant() {
        #expect(RefreshPolicy.relevantGamesChanged(old: [game()], new: [game(score: true)], teams: ["KC"]))
    }

    @Test func otherTeamChangeIsNotRelevant() {
        #expect(!RefreshPolicy.relevantGamesChanged(old: [game(), other(score: false)], new: [game(), other(score: true)], teams: ["KC"]))
    }

    @Test func missingOrNewSeasonIsRelevant() {
        var next = game()
        next.season = 2027
        #expect(RefreshPolicy.relevantGamesChanged(old: nil, new: [game()], teams: ["KC"]))
        #expect(RefreshPolicy.relevantGamesChanged(old: [game()], new: [next], teams: ["KC"]))
    }
}
