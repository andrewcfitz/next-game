import SwiftUI

@main
struct NextGameApp: App {
    var body: some Scene {
        MenuBarExtra("Next Game", systemImage: "football.fill") {
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
