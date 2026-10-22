import SwiftUI
import VocabCore

/// Where the cards of a package from "Open in Mnemit" go: a new deck named after the Anki deck,
/// or one of the decks the app lists. The package is read first, with a spinner, as the name of
/// the new deck comes from it; it goes on with the choice, so the preview doesn't read it again.
struct AnkiDestinationSheet: View {
    enum Destination: Equatable {
        case newDeck(named: String)
        case existing(KnownDeck)
    }

    /// The copy of the package, see `IncomingPackages`.
    var url: URL
    var decks: [KnownDeck]
    /// The file for the preview, and where its cards go.
    var choose: (ImportedFile, Destination) -> Void
    @State private var package: AnkiImport?
    /// Why the package could not be read.
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss

    private var fileName: String { url.lastPathComponent }

    var body: some View {
        NavigationStack {
            Group {
                if let package {
                    destinations(of: package)
                } else if let failure {
                    ContentUnavailableView {
                        Label("Import failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(failure)
                    }
                } else {
                    ProgressView("Reading “\(fileName)”…")
                }
            }
            .navigationTitle("Import Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            guard package == nil else { return }
            do {
                package = try await CardImport.loadAnki(at: url)
            } catch {
                failure = CardImport.failureMessage(error)
            }
        }
    }

    private func destinations(of package: AnkiImport) -> some View {
        let name = CardImport.deckName(forDecks: package.deckNames, fileName: fileName)
        let file = ImportedFile(ankiAt: url, package: package)
        return List {
            Section {
                Button {
                    choose(file, .newDeck(named: name))
                } label: {
                    RowLabel(title: "New Deck “\(name)”", symbol: "rectangle.stack.badge.plus")
                }
                .tint(.primary)
            } header: {
                Text("Where should the cards of “\(fileName)” go?")
                    .textCase(nil)
            }
            if !decks.isEmpty {
                Section("Decks") {
                    ForEach(decks) { deck in
                        Button {
                            choose(file, .existing(deck))
                        } label: {
                            Label {
                                Text(verbatim: deck.name)
                            } icon: {
                                Image(systemName: "rectangle.stack")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
