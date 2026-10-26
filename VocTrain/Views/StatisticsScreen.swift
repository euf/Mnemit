import SwiftUI
import VocabCore

/// The statistics of an open deck, pushed from its screen: the tiles the Mac has (Cards, Due, New, Suspended,
/// Recall Now) over the retention table. The Mac adds its charts.
struct StatisticsScreen: View {
    var document: VocabularyDocument
    @State private var figures: Figures?

    private struct Figures {
        var summary: DeckStatistics.Summary
        var retention: TrueRetention
    }

    var body: some View {
        ScrollView {
            if let figures {
                VStack(alignment: .leading, spacing: 28) {
                    SummaryTiles(summary: figures.summary)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Retention")
                            .font(.title2.weight(.semibold))
                        RetentionTables(retention: figures.retention)
                    }
                }
                .padding()
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
