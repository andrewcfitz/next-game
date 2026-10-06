import Foundation

enum FetchResult: Equatable, Sendable {
    case notModified
    case updated(Data, etag: String?)
}

struct HTTPError: Error, Equatable {
    var status: Int
}

struct NFLVerseClient: Sendable {
    static let scheduleURL = URL(string: "https://raw.githubusercontent.com/nflverse/nfldata/master/data/games.csv")!
    static let teamsURL = URL(string: "https://github.com/nflverse/nflverse-data/releases/download/teams/teams_colors_logos.csv")!

    var transport: @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }

    func fetch(_ url: URL, etag: String? = nil) async throws -> FetchResult {
        // Skip URLSession's own cache so a 304 reaches us instead of being turned back into a 200.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await transport(request)
        let http = response as? HTTPURLResponse
        switch http?.statusCode ?? 0 {
        case 304: return .notModified
        case 200..<300: return .updated(data, etag: http?.value(forHTTPHeaderField: "ETag"))
        case let status: throw HTTPError(status: status)
        }
    }
}
