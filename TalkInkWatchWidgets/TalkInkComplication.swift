import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .widgetAccentable()
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .widgetAccentable()
                VStack(alignment: .leading) {
                    Text("TalkInk")
                        .font(.headline)
                        .widgetAccentable()
                    Text("Tap to Record")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            Label("TalkInk", systemImage: "mic.fill")
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: "mic.fill")
                .font(.title3)
                .widgetAccentable()
        #endif
        @unknown default:
            Image(systemName: "mic.fill")
                .widgetAccentable()
        }
    }
}

@main
struct TalkInkComplication: Widget {
    let kind = "TalkInkComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { _ in
            ComplicationView()
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("TalkInk")
        .description("Quick access to meeting recording.")
        #if os(watchOS)
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
        #else
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        #endif
    }
}
