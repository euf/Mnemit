import SwiftUI
import WidgetKit

/// One timeline entry: the figures of the widget at `date`, `nil` before the app wrote a
/// snapshot.
struct MnemitEntry: TimelineEntry {
    var date: Date
    var state: WidgetState?
}

/// Reads the snapshot the app keeps in the shared keychain and lays a timeline over it: an
/// entry at each hour the forecast changes, at the start of each study day and at the
/// reminder (`WidgetSnapshot.timeline(from:calendar:)`). The app asks for a new one after
/// each grade, so the timeline only has to carry the widget between two visits.
struct MnemitProvider: TimelineProvider {
    var store: SnapshotStore = KeychainSnapshotStore()

    func placeholder(in context: Context) -> MnemitEntry {
        sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (MnemitEntry) -> Void) {
        let now = Date()
        // The gallery shows an example; a widget on the screen shows what is there.
        completion(context.isPreview ? sample() : MnemitEntry(date: now, state: store.read()?.state(at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MnemitEntry>) -> Void) {
        let now = Date()
        guard let snapshot = store.read() else {
            // The app reloads the widget after it wrote its first snapshot; this is the net.
            completion(Timeline(entries: [MnemitEntry(date: now, state: nil)], policy: .after(now.addingTimeInterval(1800))))
            return
        }
        completion(Timeline(entries: snapshot.timeline(from: now).map { MnemitEntry(date: $0.date, state: $0) }, policy: .atEnd))
    }

    private func sample() -> MnemitEntry {
        let now = Date()
        return MnemitEntry(
            date: now,
            state: WidgetState(date: now, reviews: 12, goal: 20, streakDays: 7, isGoalMet: false, due: 42, nextReminder: nil, secondsPerCard: 10))
    }
}

struct MnemitWidget: Widget {
    static let kind = "MnemitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MnemitProvider()) { entry in
            MnemitWidgetView(entry: entry)
                .containerBackground(WidgetContent.background, for: .widget)
        }
        .configurationDisplayName("Daily Goal")
        .description("Cards due and your progress toward today's goal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct MnemitWidgetView: View {
    var entry: MnemitEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetContent(state: entry.state, family: family)
    }
}
