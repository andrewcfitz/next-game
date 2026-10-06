import AppKit
import Observation
import ServiceManagement
import WidgetKit

@MainActor
@Observable
final class AppModel {
    private(set) var schedule: ScheduleSnapshot?
    private(set) var configuredTeams: [String] = []
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var now = Date.now

    @ObservationIgnored private let store = SnapshotStore.shared
    @ObservationIgnored private let refresher = ScheduleRefresher()
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        schedule = store.schedule
        lastError = schedule?.lastError
        startLoop()
        observeWake()
    }

    func state(for team: String) -> TeamState? {
        schedule.map { GameResolver.resolve(team: team, games: $0.games, now: now) }
    }

    var statusLine: String {
        let fetchedAt = schedule?.fetchedAt
        if let lastError {
            guard let fetchedAt else { return lastError }
            return "\(lastError) · updated \(fetchedAt.formatted(.relative(presentation: .named)))"
        }
        guard let fetchedAt else { return "Not updated yet" }
        return "Updated \(fetchedAt.formatted(.relative(presentation: .named)))"
    }

    func menuOpened() async {
        now = .now
        configuredTeams = await Self.loadConfiguredTeams()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var logosChanged = false
        if let fresh = await refresher.refreshTeamsIfStale(maxAge: RefreshPolicy.teamsMaxAge) {
            logosChanged = await LogoCache.shared.update(fresh, force: true)
        } else if let teams = store.teams?.teams {
            logosChanged = await LogoCache.shared.update(teams)
        }

        let previous = schedule?.games
        let outcome = await refresher.refreshSchedule()
        schedule = store.schedule
        now = .now
        switch outcome {
        case .changed, .unchanged:
            lastError = nil
            lastAttempt = .now
        case let .failed(message): lastError = message
        }
        // .changed fires for any game in the season; reloading on each would burn the widget budget.
        if logosChanged || (outcome == .changed
            && RefreshPolicy.relevantGamesChanged(old: previous, new: schedule?.games, teams: Set(configuredTeams))) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Ticks often but only fetches when due, so a widget added minutes before kickoff gets game-day refresh.
    private func startLoop() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                now = .now
                configuredTeams = await Self.loadConfiguredTeams()
                if RefreshPolicy.isDue(lastAttempt: lastAttempt, teams: Set(configuredTeams),
                                       games: schedule?.games ?? [], now: .now) {
                    await refresh()
                }
                try? await Task.sleep(for: .seconds(5 * 60))
            }
        }
    }

    private func observeWake() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        })
    }

    private static func loadConfiguredTeams() async -> [String] {
        let infos = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
        let teams = infos.compactMap { $0.widgetConfigurationIntent(of: SelectTeamIntent.self)?.team?.id }
        return Array(Set(teams)).sorted()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Next Game: couldn't update login item: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
