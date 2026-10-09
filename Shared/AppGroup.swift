import Foundation
#if os(macOS)
import Security
#endif

/// The App Group shared by the app and the widget extension.
enum AppGroup {
    static let infoKey = "NextGameAppGroup"

    static let id: String? = {
        #if os(macOS)
        // Read from entitlements because the Team ID prefix is filled in at signing time.
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil),
              let groups = value as? [String]
        else { return nil }
        return groups.first
        #else
        // iOS has no SecTask API, so the group comes from Info.plist, set per environment.
        return groupID(infoDictionary: Bundle.main.infoDictionary)
        #endif
    }()

    /// An unexpanded build setting means the xcconfig wasn't applied; treat it as no group rather than a bogus one.
    static func groupID(infoDictionary: [String: Any]?) -> String? {
        guard let value = infoDictionary?[infoKey] as? String, !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    /// Falls back to the process's own defaults when there's no App Group (unit tests).
    static let defaults: UserDefaults = id.flatMap { UserDefaults(suiteName: $0) } ?? .standard

    static let containerURL: URL = id.flatMap {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
    } ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "NextGame")
}
