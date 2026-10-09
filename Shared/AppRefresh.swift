import Foundation
import WidgetKit

enum WidgetTeams {
    static func configured() async -> [String] {
        let infos = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
        let teams = infos.compactMap { $0.widgetConfigurationIntent(of: SelectTeamIntent.self)?.team?.id }
        return Array(Set(teams)).sorted()
    }
}

/// The refresh both apps run: the schedule first so the status line settles quickly, then teams weekly and logos.
struct AppRefresh {
    var refresher = ScheduleRefresher()
    var store = SnapshotStore.shared
    var logos = LogoCache.shared

    func run(configuredTeams: Set<String>) async -> RefreshOutcome {
        let previous = store.schedule?.games
        let outcome = await refresher.refreshSchedule()

        var logosChanged = false
        if let fresh = await refresher.refreshTeamsIfStale(maxAge: RefreshPolicy.teamsMaxAge) {
            logosChanged = await logos.update(fresh, force: true)
        } else if let teams = store.teams?.teams {
            logosChanged = await logos.update(teams)
        }

        // .changed fires for any game in the season; reloading on each would burn the widget budget.
        if logosChanged || (outcome == .changed
            && RefreshPolicy.relevantGamesChanged(old: previous, new: store.schedule?.games, teams: configuredTeams)) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return outcome
    }
}
