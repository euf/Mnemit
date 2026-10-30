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
///
/// A deck that had no card yet, a new one, also offers Study These Now: it adds the checked cards, closes and
/// hands the new ones to `studyNow`, so the first cards of the deck are studied at once.
struct ImportPreviewSheet: View {
    var document: VocabularyDocument
    var file: ImportedFile
    private var studyNow: (([Card.ID]) -> Void)?
    /// Whether the deck had no card when the sheet opened.
    @State private var isNewDeck: Bool
    @State private var preview: CardImport.Preview?
    /// Why the file could not be read.
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.knownDeckFiles) private var knownDeckFiles

    init(document: VocabularyDocument, file: ImportedFile, preview: CardImport.Preview? = nil, studyNow: (([Card.ID]) -> Void)? = nil) {
        self.document = document
        self.file = file
        self.studyNow = studyNow
        _isNewDeck = State(initialValue: document.deck.cards.isEmpty)
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
                    ImportFailureView(message: failure)
                } else {
                    ProgressView("Reading “\(file.name)”…")
                }
            }
            // Short: between Cancel and "Add 6 Cards" a longer title is cut ("Import Car…").
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(preview?.selection.count ?? 0) Cards") {
                        if let preview { add(preview) }
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
        .safeAreaBar(edge: .bottom) {
            if isNewDeck, let studyNow, let preview, offersStudyNow(preview) {
                Button {
                    let ids = add(preview)
                    dismiss()
                    studyNow(ids)
                } label: {
                    Text("Study These Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.appAccent)
                .controlSize(.large)
                .padding(.horizontal, Spacing.margin)
                .padding(.bottom, Spacing.tight)
            }
        }
        .task { await load() }
    }

    /// A lesson's worth of new cards from a table: a package brings its own history and a library of cards is
    /// no lesson, the plan paces both.
    private func offersStudyNow(_ preview: CardImport.Preview) -> Bool {
        let cards = preview.selectedCards
        return preview.anki == nil && (1...Self.studyNowLimit).contains(cards.count) && cards.contains(where: \.isNew)
    }

    private static let studyNowLimit = 50

    /// Imports the checked cards as one change; returns their ids.
    @discardableResult
    private func add(_ preview: CardImport.Preview) -> [Card.ID] {
        let cards = preview.selectedCards
        document.importCards(cards, learningOptions: preview.learningOptions, media: preview.media)
        return cards.map(\.id)
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

/// A file that could not be read: what is wrong with it and, for an Anki package, how to export one Mnemit can read.
struct ImportFailureView: View {
    var message: String
    /// Opens the file picker again; `nil` where the sheet can't.
    var chooseAnother: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Import failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let chooseAnother {
                Button("Choose Another File", action: chooseAnother)
                    .buttonStyle(.borderedProminent)
            }
            Link("How to Export from Anki", destination: Self.exportHelp)
        }
    }

    private static let exportHelp = URL(string: "https://docs.ankiweb.net/exporting.html")!
}

private struct PreviewList: View {
    @Bindable var preview: CardImport.Preview

    var body: some View {
        List {
            Section {
                ForEach(preview.candidates) { candidate in
                    row(candidate)
                }
            } header: {
                header
            }
        }
        .listStyle(.insetGrouped)
    }

    /// The name of the deck, then the facts of the file, the cards that will be added of those it lists, and what is left out
    /// in a box of its own: cards in the file, less those left out, are the list, and the ticked ones are the button.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            if let anki = preview.anki {
                Text(anki.deckTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(preview.cardsInFile) cards in “\(preview.fileName)”")
                ForEach(preview.anki?.facts ?? [], id: \.self) { line in
                    Text(line)
                }
                ForEach(preview.otherDeckLines, id: \.self) { line in
                    Text(line)
                }
                if preview.skippedRows > 0 {
                    Text("\(preview.skippedRows) rows without a question or an answer are left out.")
                }
            }
            Text(preview.willBeAddedLine)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            let warnings = preview.anki?.warnings ?? []
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(warnings, id: \.self) { line in
                        Label {
                            Text(line)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .padding(Spacing.gap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .textCase(nil)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The question on one line, as the list shows it: a word and its article are written on two lines in Anki.
    private func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
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
                    SideText(text: oneLine(candidate.card.question), image: candidate.card.questionImage, audio: candidate.card.questionAudio)
                    SideText(
                        text: oneLine(candidate.card.answer.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? candidate.card.answer),
                        image: candidate.card.answerImage, audio: candidate.card.answerAudio
                    )
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
