import AppKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

struct LogoCacheTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "LogoCacheTests-\(UUID().uuidString)")

    static func png(side: Int) -> Data {
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    func team(_ abbr: String) -> Team {
        Team(abbr: abbr, name: abbr, primaryColor: "#000000", secondaryColor: "#FFFFFF",
             logoURL: URL(string: "https://example.com/\(abbr).png"))
    }

    @Test func resizesLargeLogos() throws {
        let small = try #require(LogoCache.resized(Self.png(side: 500)))
        let image = try #require(NSImage(data: small))
        let rep = try #require(image.representations.first)
        #expect(max(rep.pixelsWide, rep.pixelsHigh) == 128)
    }

    @Test func garbageIsRejected() {
        #expect(LogoCache.resized(Data("nope".utf8)) == nil)
    }

    @Test func downloadsOnlyMissingLogosUnlessForced() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = Counter()
        let cache = LogoCache(directory: directory) { _ in
            counter.increment()
            return Self.png(side: 500)
        }
        #expect(await cache.update([team("KC"), team("DEN")]) == true)
        #expect(counter.value == 2)
        #expect(cache.image(for: "KC") != nil)

        #expect(await cache.update([team("KC"), team("DEN")]) == false)
        #expect(counter.value == 2)

        #expect(await cache.update([team("KC")], force: true) == true)
        #expect(counter.value == 3)
    }

    @Test func missingLogoHasNoImage() {
        #expect(LogoCache(directory: directory).image(for: "KC") == nil)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
