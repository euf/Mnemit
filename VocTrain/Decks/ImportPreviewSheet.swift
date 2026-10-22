import SwiftUI
import UniformTypeIdentifiers
import VocabCore

/// A CSV or TSV file the learner picked, read into memory while the file picker still gives
/// access to it.
struct ImportedFile: Identifiable {
    let id = UUID()
    var name: String
    var data: Data

    init(name: String, data: Data) {
        self.name = name
        self.data = data
    }

    init(contentsOf url: URL) throws {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        self.init(name: url.lastPathComponent, data: try Data(contentsOf: url))
    }
}

extension View {
    /// The file picker of "Import Cards…": calls `onPick` with the file read, or tells the
    /// learner why it could not be read. Present it from another view than `deckPicker`: two
    /// `fileImporter`s on one view cancel each other.
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
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.delimitedText, .plainText]) { result in
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
/// out unchecked and says so. "Add N Cards" adds the checked ones as one change, one Undo.
struct ImportPreviewSheet: View {
    var document: VocabularyDocument
    var file: ImportedFile
    @State private var preview: CardImport.Preview?
    @Environment(\.dismiss) private var dismiss

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
                            Text("“\(file.name)” contains no rows with a question and an answer.")
                        }
                    } else {
                        PreviewList(preview: preview)
                    }
                } else {
                    ProgressView()
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
                            document.importCards(preview.selectedCards)
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
        .task {
            if preview == nil {
                preview = CardImport.preview(of: file.data, fileName: file.name, existing: document.deck.cards, created: document.clock.now)
            }
        }
    }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(preview.candidates.count) cards in “\(preview.fileName)”")
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
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
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
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
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
