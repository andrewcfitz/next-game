import SwiftUI
import Testing

struct TeamIntentTests {
    @Test func queryReturnsOnlyKnownTeams() async throws {
        let found = try await TeamQuery().entities(for: ["KC", "OAK"])
        #expect(found.map(\.id) == ["KC"])
        #expect(found.first?.name == "Kansas City Chiefs")
    }

    @Test func suggestionsAreAllTeamsByName() async throws {
        let suggested = try await TeamQuery().suggestedEntities()
        #expect(suggested.count == 32)
        #expect(suggested.first?.name == "Arizona Cardinals")
        #expect(suggested.map(\.name) == suggested.map(\.name).sorted())
    }

    @Test func hexColors() {
        #expect(Color(hex: "#E31837") != nil)
        #expect(Color(hex: "e31837") != nil)
        #expect(Color(hex: "nope") == nil)
        #expect(Color(hex: "") == nil)
    }
}
