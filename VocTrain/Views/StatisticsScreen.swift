import SwiftUI
import VocabCore

/// The statistics of an open deck, pushed from its screen: the tiles the Mac has (Cards, Due, New, Suspended,
/// Remembered Now) over the retention table, which has a section of its own. The Mac adds its charts.
struct StatisticsScreen: View {
    var document: VocabularyDocument
    @State private var figures: Figures?

    private struct Figures {
        var summary: DeckStatistics.Summary
        var retention: TrueRetention
    }

    var body: some View {
        Group {
            if let figures {
                List {
                    Section {
                        SummaryTiles(summary: figures.summary)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    Section("Retention") {
                        RetentionTables(retention: figures.retention)
                    }
                }
                .groupedList()
            } else {
                ProgressView()
                    .padding()
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let deck = document.deck
            let now = document.clock.now
            let calendar = document.calendar
            figures = Figures(
                summary: DeckStatistics.summary(of: deck, at: now, calendar: calendar),
                retention: TrueRetention(of: deck, at: now, calendar: calendar))
        }
    }
}
