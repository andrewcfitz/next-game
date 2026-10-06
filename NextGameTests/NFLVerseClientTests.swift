import Foundation
import Testing

struct NFLVerseClientTests {
    func client(_ fake: FakeTransport) -> NFLVerseClient {
        NFLVerseClient(transport: { try await fake.send($0) })
    }

    @Test func sendsETagAndBypassesTheURLCache() async throws {
        let fake = FakeTransport([.status(304)])
        let result = try await client(fake).fetch(NFLVerseClient.scheduleURL, etag: "\"abc\"")
        #expect(result == .notModified)
        let request = try #require(fake.requests.first)
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == "\"abc\"")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test func okReturnsDataAndETag() async throws {
        let fake = FakeTransport([.status(200, Data("csv".utf8), headers: ["ETag": "\"v2\""])])
        let result = try await client(fake).fetch(NFLVerseClient.scheduleURL)
        #expect(result == .updated(Data("csv".utf8), etag: "\"v2\""))
        #expect(fake.requests.first?.value(forHTTPHeaderField: "If-None-Match") == nil)
    }

    @Test func serverErrorThrows() async {
        let fake = FakeTransport([.status(503)])
        await #expect(throws: HTTPError(status: 503)) {
            try await client(fake).fetch(NFLVerseClient.scheduleURL)
        }
    }

    @Test func urlsArePinned() {
        #expect(NFLVerseClient.scheduleURL.absoluteString == "https://raw.githubusercontent.com/nflverse/nfldata/master/data/games.csv")
        #expect(NFLVerseClient.teamsURL.absoluteString == "https://github.com/nflverse/nflverse-data/releases/download/teams/teams_colors_logos.csv")
    }
}
