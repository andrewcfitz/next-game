import Foundation
import Testing

struct WidgetFetchTests {
    let kickoff = Date(timeIntervalSince1970: 1_790_000_000)
    let hour: TimeInterval = 3600

    var games: [Game] {
        [Game(id: "g", season: 2026, week: 5, gameType: "REG", kickoff: kickoff, awayTeam: "KC", homeTeam: "BUF",
              awayScore: nil, homeScore: nil, stadium: nil, spread: nil)]
    }

    func fetch(age: TimeInterval?, team: String? = "KC", now: Date, app: Bool) -> Bool {
        RefreshPolicy.widgetShouldFetch(snapshotAge: age, team: team, games: games, now: now, appIsTheFetcher: app)
    }

    @Test func noSnapshotAlwaysFetches() {
        #expect(fetch(age: nil, now: kickoff - 48 * hour, app: true))
        #expect(fetch(age: nil, now: kickoff - 48 * hour, app: false))
    }

    @Test func macWaitsTwelveHours() {
        #expect(!fetch(age: 11 * hour, now: kickoff - hour, app: true))
        #expect(fetch(age: 12 * hour, now: kickoff - hour, app: true))
    }

    @Test func iOSFollowsTheRefreshIntervalAwayFromGames() {
        #expect(!fetch(age: 5 * hour, now: kickoff - 48 * hour, app: false))
        #expect(fetch(age: 6 * hour, now: kickoff - 48 * hour, app: false))
    }

    @Test func iOSRefetchesEveryFifteenMinutesAroundTheGame() {
        #expect(!fetch(age: 14 * 60, now: kickoff + hour, app: false))
        #expect(fetch(age: 15 * 60, now: kickoff + hour, app: false))
    }

    @Test func iOSWithoutATeamUsesTheNormalInterval() {
        #expect(!fetch(age: 5 * hour, team: nil, now: kickoff + hour, app: false))
        #expect(fetch(age: 6 * hour, team: nil, now: kickoff + hour, app: false))
    }
}
