import SwiftUI

@main
struct NextGameiOSApp: App {
    @State private var model = IOSAppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TeamsView()
                .environment(model)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: Task { await model.becameActive() }
            case .background: model.scheduleBackgroundRefresh()
            default: break
            }
        }
        .backgroundTask(.appRefresh(IOSAppModel.refreshTaskID)) {
            await model.backgroundRefresh()
        }
    }
}
