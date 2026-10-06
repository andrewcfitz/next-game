import Foundation

/// Replays canned HTTP replies in order and records requests.
final class FakeTransport: @unchecked Sendable {
    enum Reply {
        case status(Int, Data = Data(), headers: [String: String] = [:])
        case failure(URLError.Code)
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private var recorded: [URLRequest] = []

    init(_ replies: [Reply]) { self.replies = replies }

    var requests: [URLRequest] { lock.withLock { recorded } }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let reply: Reply = lock.withLock {
            recorded.append(request)
            return replies.isEmpty ? .failure(.resourceUnavailable) : replies.removeFirst()
        }
        switch reply {
        case let .status(code, data, headers):
            return (data, HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: headers)!)
        case let .failure(code):
            throw URLError(code)
        }
    }
}
