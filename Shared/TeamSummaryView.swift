import SwiftUI

struct TeamSummaryView: View {
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
