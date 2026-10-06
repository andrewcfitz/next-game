import AppKit
import SwiftUI

@main
struct NextGameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(model)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window("Next Game", id: SettingsView.windowID) {
            SettingsView()
                .environment(model)
        }
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

extension Notification.Name {
    static let showSettings = Notification.Name("NextGameShowSettings")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// There's no Dock icon, so opening the app again from Finder or Spotlight shows settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NotificationCenter.default.post(name: .showSettings, object: nil)
        return false
    }
}

struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "football.fill")
            // The label is the one view that's always alive, so it handles reopen.
            .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
                openWindow(id: SettingsView.windowID)
                NSApp.activate()
            }
    }
}
