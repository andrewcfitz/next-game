import SwiftUI
import WidgetKit

struct NextGameWidgetView: View {
    var entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let team = entry.team {
            if let state = entry.state {
                if family == .systemMedium {
                    HStack(alignment: .top, spacing: 12) {
                        StateView(team: team, state: state, entry: entry)
                        Divider()
                        LaterGamesView(team: team, games: entry.later, now: entry.date)
                    }
                } else {
                    StateView(team: team, state: state, entry: entry)
                }
            } else {
                message(entry.hasSchedule ? "No games found" : "Waiting for schedule")
            }
        } else {
            message("Edit the widget to pick a team")
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StateView: View {
    var team: String
    var state: TeamState
    var entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch state {
            case let .upcoming(next, last, isBye):
                header(next)
                Text(GameFormatting.countdown(to: next.kickoff, now: entry.date))
                    .font(.title2.bold())
                Text(GameFormatting.kickoff(next.kickoff, now: entry.date))
                    .font(.caption)
                Spacer(minLength: 0)
                if isBye {
                    Text("Bye this week").font(.caption2).foregroundStyle(.secondary)
                }
                if let last {
                    Text(GameFormatting.result(last, for: team)).font(.caption).foregroundStyle(.secondary)
                }
            case let .inProgress(game):
                header(game)
                Text(GameFormatting.liveScore(game, for: team))
                    .font(.title3.bold())
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            case let .offseason(last):
                HStack {
                    LogoView(abbr: team, team: entry.teams[team])
                    Text(team).font(.headline)
                }
                Text("Offseason").font(.title3.bold())
                Spacer(minLength: 0)
                if let last {
                    Text(GameFormatting.result(last, for: team)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ game: Game) -> some View {
        let opponent = game.opponent(of: team)
        return HStack(spacing: 6) {
            LogoView(abbr: team, team: entry.teams[team], size: 22)
            Text(game.isHome(team) ? "vs" : "@").font(.caption).foregroundStyle(.secondary)
            LogoView(abbr: opponent, team: entry.teams[opponent], size: 22)
            Text(opponent).font(.headline)
        }
    }
}

struct LaterGamesView: View {
    var team: String
    var games: [Game]
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coming up").font(.caption2).foregroundStyle(.secondary)
            ForEach(games) { game in
                VStack(alignment: .leading, spacing: 0) {
                    Text(GameFormatting.matchup(game, for: team)).font(.caption.bold())
                    Text(GameFormatting.kickoff(game.kickoff, now: now)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct LogoView: View {
    var abbr: String
    var team: Team?
    var size: CGFloat = 28

    var body: some View {
        if let image = LogoCache.shared.image(for: abbr) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(abbr)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(team.flatMap { Color(hex: $0.primaryColor) } ?? .gray))
        }
    }
}
