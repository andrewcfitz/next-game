import Foundation

enum RefreshOutcome: Equatable, Sendable {
    case unchanged
    case changed
    case failed(String)
}

/// Downloads nflverse data into the snapshot store. Never replaces good data with bad.
struct ScheduleRefresher: Sendable {
    var client = NFLVerseClient()
    var store = SnapshotStore.shared
    var now: @Sendable () -> Date = { .now }

    func refreshSchedule() async -> RefreshOutcome {
        let previous = store.schedule
        do {
            switch try await client.fetch(NFLVerseClient.scheduleURL, etag: previous?.etag) {
            case .notModified:
                guard var snapshot = previous else { return .unchanged }
                snapshot.fetchedAt = now()
                snapshot.lastError = nil
                store.schedule = snapshot
                return .unchanged
            case let .updated(data, etag):
                let parsed = try ScheduleParser.parse(data)
                store.schedule = ScheduleSnapshot(season: parsed.season, games: parsed.games, etag: etag,
                                                  fetchedAt: now(), lastError: nil)
                return parsed.games == previous?.games ? .unchanged : .changed
            }
        } catch {
            let message = Self.describe(error)
            if var snapshot = previous {
                snapshot.lastError = message
                store.schedule = snapshot
            }
            return .failed(message)
        }
    }

    func refreshTeamsIfStale(maxAge: TimeInterval = 7 * 86400) async -> [Team]? {
        if let cached = store.teams, now().timeIntervalSince(cached.fetchedAt) < maxAge { return nil }
        guard case let .updated(data, _) = try? await client.fetch(NFLVerseClient.teamsURL),
              let teams = try? TeamsParser.parse(data)
        else { return nil }
        store.teams = TeamsSnapshot(teams: teams, fetchedAt: now())
        return teams
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case let error as HTTPError: "HTTP \(error.status)"
        case is ParseError: "Couldn't read the schedule"
        default: error.localizedDescription
        }
    }
}
