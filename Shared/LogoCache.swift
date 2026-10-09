import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Team logos on disk in the App Group, because widgets can't load remote images while rendering.
struct LogoCache: Sendable {
    static let shared = LogoCache(directory: AppGroup.containerURL.appending(path: "Logos", directoryHint: .isDirectory))

    let directory: URL
    var download: @Sendable (URL) async throws -> Data

    init(directory: URL, download: @escaping @Sendable (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 }) {
        self.directory = directory
        self.download = download
    }

    func fileURL(for abbr: String) -> URL {
        directory.appending(path: "\(abbr).png")
    }

    func image(for abbr: String) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL(for: abbr) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    @discardableResult
    func update(_ teams: [Team], force: Bool = false) async -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return await withTaskGroup(of: Bool.self) { group in
            for team in teams {
                guard let url = team.logoURL else { continue }
                let file = fileURL(for: team.abbr)
                if !force, FileManager.default.fileExists(atPath: file.path()) { continue }
                group.addTask { [download] in
                    guard let data = try? await download(url), let png = Self.resized(data) else { return false }
                    return (try? png.write(to: file, options: .atomic)) != nil
                }
            }
            return await group.reduce(false) { $0 || $1 }
        }
    }

    /// ESPN serves 500px logos; widget extensions have tight memory limits.
    static func resized(_ data: Data, side: Int = 128) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: side,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary)
        else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
