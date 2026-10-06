import Foundation
import Testing

struct ScheduleRefresherTests {
    let store = SnapshotStore(defaults: UserDefaults(suiteName: "NextGameTests.\(UUID().uuidString)")!)
    let clock = Date(timeIntervalSince1970: 1_790_000_000)
    let csv = Data(ScheduleParserTests.fixture.utf8)

    func refresher(_ fake: FakeTransport, now: Date? = nil) -> ScheduleRefresher {
        let date = now ?? clock
        return ScheduleRefresher(client: NFLVerseClient(transport: { try await fake.send($0) }),
                                 store: store, now: { date })
    }

    @Test func firstFetchStoresTheSeason() async {
        let fake = FakeTransport([.status(200, csv, headers: ["ETag": "\"v1\""])])
        #expect(await refresher(fake).refreshSchedule() == .changed)
        #expect(store.schedule?.season == 2026)
        #expect(store.schedule?.games.count == 3)
        #expect(store.schedule?.etag == "\"v1\"")
        #expect(store.schedule?.fetchedAt == clock)
    }

    @Test func notModifiedOnlyTouchesTheTimestamp() async {
        _ = await refresher(FakeTransport([.status(200, csv, headers: ["ETag": "\"v1\""])])).refreshSchedule()
        let later = clock + 600
        let fake = FakeTransport([.status(304)])
        #expect(await refresher(fake, now: later).refreshSchedule() == .unchanged)
        #expect(fake.requests.first?.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"")
        #expect(store.schedule?.fetchedAt == later)
        #expect(store.schedule?.games.count == 3)
    }

    @Test func sameContentIsUnchanged() async {
        _ = await refresher(FakeTransport([.status(200, csv)])).refreshSchedule()
        #expect(await refresher(FakeTransport([.status(200, csv)])).refreshSchedule() == .unchanged)
    }

    @Test func networkErrorKeepsGames() async {
        _ = await refresher(FakeTransport([.status(200, csv)])).refreshSchedule()
        let outcome = await refresher(FakeTransport([.failure(.notConnectedToInternet)])).refreshSchedule()
        guard case .failed = outcome else { Issue.record("expected failure, got \(outcome)"); return }
        #expect(store.schedule?.games.count == 3)
        #expect(store.schedule?.lastError != nil)
    }

    @Test func garbageKeepsGames() async {
        _ = await refresher(FakeTransport([.status(200, csv)])).refreshSchedule()
        let outcome = await refresher(FakeTransport([.status(200, Data("<html>oops</html>".utf8))])).refreshSchedule()
        guard case .failed = outcome else { Issue.record("expected failure, got \(outcome)"); return }
        #expect(store.schedule?.games.count == 3)
    }

    @Test func errorWithoutCacheLeavesNoSnapshot() async {
        let outcome = await refresher(FakeTransport([.status(500)])).refreshSchedule()
        #expect(outcome == .failed("HTTP 500"))
        #expect(store.schedule == nil)
    }

    @Test func successClearsAnEarlierError() async {
        _ = await refresher(FakeTransport([.status(200, csv, headers: ["ETag": "\"v1\""])])).refreshSchedule()
        _ = await refresher(FakeTransport([.status(500)])).refreshSchedule()
        _ = await refresher(FakeTransport([.status(304)])).refreshSchedule()
        #expect(store.schedule?.lastError == nil)
    }

    @Test func teamsAreOnlyFetchedWhenStale() async {
        let teamsCSV = Data(TeamsParserTests.fixture.utf8)
        let fake = FakeTransport([.status(200, teamsCSV)])
        #expect(await refresher(fake).refreshTeamsIfStale()?.map(\.abbr) == ["KC", "LA"])
        #expect(store.teams?.teams.count == 2)

        let idle = FakeTransport([])
        #expect(await refresher(idle, now: clock + 86400).refreshTeamsIfStale() == nil)
        #expect(idle.requests.isEmpty)

        let stale = FakeTransport([.status(200, teamsCSV)])
        #expect(await refresher(stale, now: clock + 8 * 86400).refreshTeamsIfStale() != nil)
    }
}
