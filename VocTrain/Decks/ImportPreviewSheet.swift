import SwiftUI
import UniformTypeIdentifiers
import VocabCore

/// A file the learner picked or opened in Mnemit: a CSV or TSV file, read into memory while the
/// file picker still gives access to it, or an Anki package, which stays a file and is read
/// off the main thread by the preview, as it can be large.
struct ImportedFile: Identifiable {
    enum Content {
        case table(Data)
        /// The package at the URL; the second is the package read already, if it was.
        case anki(URL, AnkiImport?)
    }

    let id = UUID()
    var name: String
    var content: Content
    /// Whether the cards go to a new deck, made for the package: it takes the FSRS settings of the
    /// Anki preset most cards use.
    var isNewDeck = false

    init(name: String, data: Data) {
        self.name = name
        content = .table(data)
    }

    init(ankiAt url: URL, package: AnkiImport? = nil) {
        name = url.lastPathComponent
        content = .anki(url, package)
    }

    /// The file of the picker: a package is read later, a table now.
    init(contentsOf url: URL) throws {
        if url.isAnkiPackage {
            self.init(ankiAt: url)
        } else {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            self.init(name: url.lastPathComponent, data: try Data(contentsOf: url))
        }
    }

    /// The text of a table, `nil` for a package.
    var data: Data? {
        if case let .table(data) = content { data } else { nil }
    }
}

extension View {
    /// The file picker of "Import Cards…", for a CSV or TSV file or an Anki package: calls
    /// `onPick` with the file, or tells the learner why it could not be read. Present it from
    /// another view than `deckPicker`: two `fileImporter`s on one view cancel each other.
    func cardFileImporter(isPresented: Binding<Bool>, onPick: @escaping (ImportedFile) -> Void) -> some View {
        modifier(CardFileImporter(isPresented: isPresented, onPick: onPick))
    }
}

private struct CardFileImporter: ViewModifier {
    @Binding var isPresented: Bool
    var onPick: (ImportedFile) -> Void
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.delimitedText, .plainText] + UTType.ankiPackages) { result in
                switch result {
                case let .success(url):
                    do {
                        onPick(try ImportedFile(contentsOf: url))
                    } catch {
                        failure = error.localizedDescription
                    }
                case let .failure(error):
                    if (error as? CocoaError)?.code != .userCancelled {
                        failure = error.localizedDescription
                    }
                }
            }
            .alert("Import failed", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") {}
            } message: {
                Text(failure ?? "")
            }
    }
}

/// The cards of an import file, to choose which ones to add to the deck: the Mac's preview as a
/// list with a checkmark per card. A card the deck has, or an earlier one of the file, starts
/// out unchecked and says so. "Add N Cards" adds the checked ones as one change, one Undo; the
/// cards of an Anki package come with their review history. A package is read while a spinner
/// shows.
struct ImportPreviewSheet: View {
    var document: VocabularyDocument
    var file: ImportedFile
    @State private var preview: CardImport.Preview?
    /// Why the file could not be read.
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.knownDeckFiles) private var knownDeckFiles

    init(document: VocabularyDocument, file: ImportedFile, preview: CardImport.Preview? = nil) {
        self.document = document
        self.file = file
        _preview = State(initialValue: preview)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let preview {
                    if preview.candidates.isEmpty {
                        ContentUnavailableView {
                            Label("No Cards", systemImage: "tray")
                        } description: {
                            if let anki = preview.anki {
                                Text(anki.noCardsMessage(fileName: file.name))
                            } else {
                                Text("“\(file.name)” contains no rows with a question and an answer.")
                            }
                        }
                    } else {
                        PreviewList(preview: preview)
                    }
                } else if let failure {
                    ContentUnavailableView {
                        Label("Import failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(failure)
                    }
                } else {
                    ProgressView("Reading “\(file.name)”…")
                }
            }
            .navigationTitle("Import Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(preview?.selection.count ?? 0) Cards") {
                        if let preview {
                            document.importCards(preview.selectedCards, learningOptions: preview.learningOptions(over: document.deck.learningOptions), media: preview.media)
                        }
                        dismiss()
                    }
                    .disabled(preview?.selection.isEmpty ?? true)
                }
                if let preview, !preview.candidates.isEmpty {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Select All") { preview.selection = Set(preview.candidates.map(\.id)) }
                        Spacer()
                        Button("Select None") { preview.selection = [] }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard preview == nil else { return }
        let elsewhere = await knownDeckFiles.wordIndex(excluding: document.packageURL)
        switch file.content {
        case let .table(data):
            preview = CardImport.preview(of: data, fileName: file.name, existing: document.deck.cards, elsewhere: elsewhere, created: document.clock.now)
        case let .anki(url, known):
            do {
                let package: AnkiImport
                if let known {
                    package = known
                } else {
                    package = try await CardImport.loadAnki(at: url)
                }
                preview = await CardImport.ankiPreview(of: package, fileName: file.name, for: document, isNewDeck: file.isNewDeck, elsewhere: elsewhere)
            } catch {
                failure = CardImport.failureMessage(error)
            }
        }
    }
}

private struct PreviewList: View {
    @Bindable var preview: CardImport.Preview

    var body: some View {
        List {
            if preview.makesDeck {
                WordsInDeckSection(introducesNewCards: $preview.introducesNewCards)
            }
            Section {
                ForEach(preview.candidates) { candidate in
                    row(candidate)
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    if let anki = preview.anki {
                        Text(anki.deckTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    Text("\(preview.candidates.count) cards in “\(preview.fileName)”")
                    ForEach(preview.anki?.lines ?? [], id: \.self) { line in
                        Text(line)
                    }
                    ForEach(preview.otherDeckLines, id: \.self) { line in
                        Text(line)
                    }
                    if preview.skippedRows > 0 {
                        Text("\(preview.skippedRows) rows without a question or an answer are left out.")
                    }
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(_ candidate: CardImporter.Candidate) -> some View {
        let isSelected = preview.selection.contains(candidate.id)
        return Button {
            if isSelected {
                preview.selection.remove(candidate.id)
            } else {
                preview.selection.insert(candidate.id)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(isSelected ? Color.appAccentOnRaised : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.card.question)
                    Text(candidate.card.answer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !candidate.card.hint.isEmpty {
                        Text(candidate.card.hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let duplicate = candidate.duplicate {
                        Label {
                            switch duplicate {
                            case .inDeck:
                                Text("Already in this deck")
                            case let .inFile(question, answer):
                                Text("Already earlier in the file: \(question) → \(answer)")
                            case let .inOtherDeck(match):
                                Text(match.alsoInLine)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else if let similar = candidate.similar {
                        Label {
                            Text(similar.similarLine)
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
