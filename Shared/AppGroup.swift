import Foundation
import Security

/// The App Group shared by the app and the widget extension.
enum AppGroup {
    /// Read from this process's entitlements because the Team ID prefix is filled in at signing time.
    static let id: String? = {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil),
              let groups = value as? [String]
        else { return nil }
        return groups.first
    }()

    /// Falls back to the process's own defaults when there's no App Group (unit tests).
    static let defaults: UserDefaults = id.flatMap { UserDefaults(suiteName: $0) } ?? .standard

    static let containerURL: URL = id.flatMap {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
    } ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "NextGame")
}
