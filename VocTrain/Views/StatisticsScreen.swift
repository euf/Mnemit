import SwiftUI
import VocabCore

/// The statistics of an open deck: its retention tables, pushed from the deck's More menu.
/// What today's session takes is on the deck screen.
struct StatisticsScreen: View {
    var document: VocabularyDocument
    @State private var retention: TrueRetention?

    var body: some View {
        ScrollView {
            if let retention {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Retention")
                        .font(.title2.weight(.semibold))
                    RetentionTables(retention: retention)
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
            retention = TrueRetention(of: document.deck, at: document.clock.now, calendar: document.calendar)
        }
    }
}
