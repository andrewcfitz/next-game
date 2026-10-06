import SwiftUI
import WidgetKit

@main
struct NextGameWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextGameWidget()
    }
}

struct NextGameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextGameWidget", provider: StubProvider()) { _ in
            Text("Next Game")
                .containerBackground(.background, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StubEntry: TimelineEntry {
    var date: Date
}

struct StubProvider: TimelineProvider {
    func placeholder(in context: Context) -> StubEntry { StubEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (StubEntry) -> Void) { completion(StubEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StubEntry>) -> Void) {
        completion(Timeline(entries: [StubEntry(date: .now)], policy: .never))
    }
}
