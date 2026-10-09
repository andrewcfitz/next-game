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
        GameFormatting.statusLine(fetchedAt: schedule?.fetchedAt, lastError: lastError, now: .now)
    }

    func menuOpened() async {
        now = .now
        configuredTeams = await WidgetTeams.configured()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let outcome = await AppRefresh().run(configuredTeams: Set(configuredTeams))
        schedule = store.schedule
        now = .now
        switch outcome {
        case .changed, .unchanged:
            lastError = nil
            lastAttempt = .now
        case let .failed(message): lastError = message
        }
    }

    /// Ticks often but only fetches when due, so a widget added minutes before kickoff gets game-day refresh.
    private func startLoop() {
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                now = .now
                configuredTeams = await WidgetTeams.configured()
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
