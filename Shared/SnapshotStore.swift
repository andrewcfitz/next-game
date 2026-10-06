import Foundation

struct ScheduleSnapshot: Codable, Equatable, Sendable {
    var season: Int
    var games: [Game]
    var etag: String?
    var fetchedAt: Date
    var lastError: String?
}

struct TeamsSnapshot: Codable, Equatable, Sendable {
    var teams: [Team]
    var fetchedAt: Date
}

/// Cached data shared by the app and widget through App Group defaults.
struct SnapshotStore: @unchecked Sendable {
    static let shared = SnapshotStore(defaults: AppGroup.defaults)

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var schedule: ScheduleSnapshot? {
        get { load(ScheduleSnapshot.self, key: "schedule") }
        nonmutating set { save(newValue, key: "schedule") }
    }

    var teams: TeamsSnapshot? {
        get { load(TeamsSnapshot.self, key: "teams") }
        nonmutating set { save(newValue, key: "teams") }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
