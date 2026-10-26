import SwiftUI
import VocabCore

/// The Progress page of the Mac's window: the iPhone's Progress screen over every deck, with How It Works as a sheet.
struct ProgressPage: View {
    var shell: Shell
    @State private var showsHowItWorks = false

    var body: some View {
        NavigationStack {
            if let progress = shell.ring.progress {
                ProgressScreen(progress: progress) {
                    Button("How It Works", systemImage: "gauge.with.dots.needle.33percent") { showsHowItWorks = true }
                        .buttonStyle(.link)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showsHowItWorks) {
            HowItWorksSheet(decks: shell.decks, folder: shell.folder)
        }
    }
}

/// "How It Works" over the decks as they are when the sheet opens, with Done.
struct HowItWorksSheet: View {
    var decks: OpenDecks
    var folder: DeckFolder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HowTodayWorksLoader(decks: decks, folder: folder)
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Spacing.margin)
        }
        .frame(width: 520, height: 640)
    }
}
