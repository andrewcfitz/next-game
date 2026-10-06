import AppIntents
import WidgetKit

struct TeamEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
    static let defaultQuery = TeamQuery()

    var id: String
    var name: String

    init(abbr: String) {
        id = abbr
        name = NFLTeams.name(for: abbr)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TeamQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TeamEntity] {
        identifiers.filter(NFLTeams.abbrs.contains).map(TeamEntity.init(abbr:))
    }

    func suggestedEntities() async throws -> [TeamEntity] {
        NFLTeams.all.sorted { $0.name < $1.name }.map { TeamEntity(abbr: $0.abbr) }
    }
}

/// Lives in Shared so the app can read which teams the widgets follow.
struct SelectTeamIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Team"
    static let description = IntentDescription("Choose the team this widget follows.")

    @Parameter(title: "Team")
    var team: TeamEntity?
}
