import SwiftUI

struct TeamsView: View {
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if model.hasLoadedTeams && model.configuredTeams.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a Next Game widget").font(.headline)
                            Text("Home Screen: touch and hold an empty spot, tap Edit, then Add Widget, and choose Next Game.")
                            Text("Lock Screen: touch and hold the Lock Screen, tap Customize, then the widget area.")
                            Text("Then touch and hold the widget, tap Edit Widget, and pick a team.")
                        }
                        .font(.callout)
                        .padding(.vertical, 4)
                    }
                }
                ForEach(model.configuredTeams, id: \.self) { team in
                    TeamSummaryView(team: team, state: model.state(for: team), now: model.now)
                        .padding(.vertical, 4)
                }
                Section {
                    Text(model.statusLine)
                        .font(.footnote)
                        .foregroundStyle(model.lastError == nil ? Color.secondary : Color.red)
                }
            }
            .navigationTitle("Next Game")
            .refreshable { await model.becameActive() }
        }
    }
}
