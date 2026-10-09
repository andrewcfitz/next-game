import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.configuredTeams.isEmpty {
                Text("Add a Next Game widget and pick a team.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.configuredTeams, id: \.self) { team in
                TeamSummaryView(team: team, state: model.state(for: team), now: model.now)
            }
            Divider()
            HStack {
                Text(model.statusLine)
                    .font(.caption)
                    .foregroundStyle(model.lastError == nil ? Color.secondary : Color.red)
                    .lineLimit(2)
                Spacer()
                Button("Refresh") { Task { await model.refresh() } }
                    .disabled(model.isRefreshing)
            }
            HStack {
                Button("Settings…") {
                    openWindow(id: SettingsView.windowID)
                    NSApp.activate()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 300)
        .task { await model.menuOpened() }
    }
}
