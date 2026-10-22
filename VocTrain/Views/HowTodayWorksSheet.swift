import SwiftUI
import VocabCore

/// The sheet "How Today Works": the figures under the ring and the rounds (`HowTodayWorksView`), with a
/// Done button; a spinner while `content` is `nil`.
struct HowTodayWorksSheet: View {
    var content: HowTodayWorks?
    var done: () -> Void

    var body: some View {
        NavigationStack {
            HowTodayWorksView(content: content)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                    }
                }
        }
    }
}

/// The info button of Today. The sheet it opens reads the files of the decks when it appears and replays
/// their logs off the main actor, so it shows the figures Today shows.
struct HowTodayWorksButton: View {
    var decks: [KnownDeck]
    var now: Date
    @State private var isShown = false
    @State private var content: HowTodayWorks?

    var body: some View {
        Button("How Today Works", systemImage: "info.circle") {
            content = nil
            isShown = true
        }
        .disabled(decks.isEmpty)
        .sheet(isPresented: $isShown) {
            HowTodayWorksSheet(content: content) { isShown = false }
                .task {
                    let files = decks.map(\.url)
                    let now = now
                    let swipes = SwipeTally.shared.counts(at: now)
                    content = await Task.detached(priority: .utility) { HowTodayWorks.read(files, at: now, swipes: swipes) }.value
                }
        }
    }
}
