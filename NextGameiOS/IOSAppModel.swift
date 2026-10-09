import BackgroundTasks
import Foundation
import Observation

@MainActor
@Observable
final class IOSAppModel {
    nonisolated static let refreshTaskID = (Bundle.main.bundleIdentifier ?? "biz.fitz.NextGame") + ".refresh"

    private(set) var schedule: ScheduleSnapshot?
    private(set) var configuredTeams: [String] = []
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    private(set) var now = Date.now

    @ObservationIgnored private let store = SnapshotStore.shared

    init() {
        schedule = store.schedule
        lastError = schedule?.lastError
    }

    func state(for team: String) -> TeamState? {
        schedule.map { GameResolver.resolve(team: team, games: $0.games, now: now) }
    }

    var statusLine: String {
        GameFormatting.statusLine(fetchedAt: schedule?.fetchedAt, lastError: lastError, now: now)
    }

    /// The widget does most fetching on iOS; opening the app is a cheap extra (usually a 304).
    func becameActive() async {
        now = .now
        configuredTeams = await WidgetTeams.configured()
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let outcome = await AppRefresh().run(configuredTeams: Set(configuredTeams))
        schedule = store.schedule
        now = .now
        if case let .failed(message) = outcome { lastError = message } else { lastError = nil }
    }

    /// iOS decides when, or whether, this runs; it only ever helps the widget's own fetching.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = .now + RefreshPolicy.interval(for: Set(configuredTeams), games: schedule?.games ?? [], now: .now)
        try? BGTaskScheduler.shared.submit(request)
    }

    func backgroundRefresh() async {
        configuredTeams = await WidgetTeams.configured()
        await refresh()
        scheduleBackgroundRefresh()
    }
}
