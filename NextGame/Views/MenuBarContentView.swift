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
                TeamRow(team: team, state: model.state(for: team), now: model.now)
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

private struct TeamRow: View {
    var team: String
    var state: TeamState?
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(NFLTeams.name(for: team)).font(.headline)
            switch state {
            case let .upcoming(next, last, isBye)?:
                Text("\(GameFormatting.matchup(next, for: team)) · \(GameFormatting.kickoff(next.kickoff, now: now)) (\(GameFormatting.countdown(to: next.kickoff, now: now)))")
                if isBye { Text("Bye this week").foregroundStyle(.secondary) }
                if let last { Text("Last: \(GameFormatting.result(last, for: team))").foregroundStyle(.secondary) }
            case let .inProgress(game)?:
                Text("\(GameFormatting.matchup(game, for: team)) · \(GameFormatting.liveScore(game, for: team))")
            case let .offseason(last)?:
                Text("Offseason")
                if let last { Text("Last: \(GameFormatting.result(last, for: team))").foregroundStyle(.secondary) }
            case nil:
                Text("Waiting for schedule").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}
