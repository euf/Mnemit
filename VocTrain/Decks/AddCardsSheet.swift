import SwiftUI
import VocabCore

/// "Add Cards": a sheet with two ways in. One Card has Question, Answer and Hint, and
/// Add keeps the sheet open for the next card; From a List takes the lines "word =
/// translation" of a lesson, as the Mac's Lesson Words does, with a preview of the cards.
/// Every addition is one undo step of the document.
///
/// Done adds what is typed, if it can be added, and closes; Cancel closes without it and
/// asks first if something is typed. The fields of the two ways keep their text while the
/// other one is shown.
struct AddCardsSheet: View {
    private enum Mode: Hashable {
        case oneCard, fromList
    }

    private enum Field: Hashable {
        case question, answer, hint, list
    }

    @ObservedObject var document: VocabularyDocument
    @Environment(\.dismiss) private var dismiss

    @State private var mode = Mode.oneCard
    @State private var question = ""
    @State private var answer = ""
    @State private var hint = ""
    /// Remembered: a learner who adds words in pairs does so every time.
    @AppStorage("addCards.bothDirections") private var bothDirections = true
    @State private var listText = ""
    /// The rows of the preview the learner switched against their default, by `Row.id`.
    @State private var flipped: Set<String> = []
    /// The cards added since the sheet opened, for the confirmation.
    @State private var addedInSession = 0
    /// Counts the additions, so each one restarts the time its confirmation shows.
    @State private var additions = 0
    @State private var showsConfirmation = false
    @State private var asksToDiscard = false
    @FocusState private var focus: Field?
    /// The room of the list's editor, a few lines at any text size.
    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 160

    /// - Parameters: The rest is what the sheet starts with; the snapshot tests show it
    ///   with the fields filled, or just after an addition of `added` cards.
    init(document: VocabularyDocument, showsList: Bool = false, question: String = "", answer: String = "", hint: String = "", list: String = "", added: Int = 0) {
        self.document = document
        _mode = State(initialValue: showsList ? .fromList : .oneCard)
        _question = State(initialValue: question)
        _answer = State(initialValue: answer)
        _hint = State(initialValue: hint)
        _listText = State(initialValue: list)
        _addedInSession = State(initialValue: added)
        _showsConfirmation = State(initialValue: added > 0)
    }

    // MARK: State of the fields

    /// `nil` until question and answer are filled in.
    private var text: CardText? { CardText(question: question, answer: answer, hint: hint) }

    private var hasTypedText: Bool {
        [question, answer, hint, listText].contains { !CardText.trimmed($0).isEmpty }
    }

    private var preview: WordListPreview {
        WordListPreview(text: listText, deck: document.deck, created: document.clock.now)
    }

    private func isSelected(_ row: WordListPreview.Row) -> Bool {
        row.isSelectedByDefault != flipped.contains(row.id)
    }

    /// What Add would do now, the cards of the checked rows.
    private func selectedCards(of preview: WordListPreview) -> [Card] {
        let cards = preview.rows.filter(isSelected).flatMap(\.cards)
        // Every recognition card first, then every production card, as the Mac adds them.
        return cards.filter { $0.kind != .production } + cards.filter { $0.kind == .production }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Add Cards", selection: $mode) {
                        Text("One Card").tag(Mode.oneCard)
                        Text("From a List").tag(Mode.fromList)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                switch mode {
                case .oneCard: oneCard
                case .fromList: fromList
                }
            }
            .navigationTitle("Add Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focus == .list {
                        Spacer()
                        Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") { focus = nil }
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .safeAreaBar(edge: .bottom) { addButton }
            .overlay(alignment: .top) {
                if showsConfirmation {
                    ConfirmationBadge(count: addedInSession)
                        .transition(.opacity)
                }
            }
            .animation(.snappy, value: showsConfirmation)
            .task(id: additions) {
                guard showsConfirmation else { return }
                try? await Task.sleep(for: .seconds(2))
                showsConfirmation = false
            }
            .defaultFocus($focus, .question)
            .onChange(of: mode) { focus = mode == .oneCard ? .question : .list }
            .confirmationDialog("Discard what you typed?", isPresented: $asksToDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
            }
        }
        // A swipe down would lose the text; Cancel asks.
        .interactiveDismissDisabled(hasTypedText)
    }

    // MARK: One card

    @ViewBuilder
    private var oneCard: some View {
        Section {
            TextField("Question", text: $question)
                .focused($focus, equals: .question)
                .submitLabel(.next)
                .onSubmit { focus = .answer }
            TextField("Answer", text: $answer, prompt: Text("Answer (alternatives separated by /)"))
                .focused($focus, equals: .answer)
                .submitLabel(.next)
                .onSubmit { focus = .hint }
            TextField("Hint", text: $hint, prompt: Text("Hint (optional)"))
                .focused($focus, equals: .hint)
                .submitLabel(.done)
                .onSubmit(addOne)
        } footer: {
            if let duplicate = document.deck.cards(withQuestion: question).first {
                Label {
                    Text("Already in this deck: \(duplicate.question) → \(duplicate.answer)")
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            }
        }
        // Words with a typed hint, an article or an accent are no good to autocorrect.
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

        Section {
            Toggle("Both directions", isOn: $bothDirections)
        } footer: {
            Text("Adds a second card that asks the other way round. It unlocks once you know the first.")
        }
    }

    // MARK: From a list

    @ViewBuilder
    private var fromList: some View {
        let preview = preview
        Section {
            TextEditor(text: $listText)
                .focused($focus, equals: .list)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: editorHeight)
                .overlay(alignment: .topLeading) {
                    if listText.isEmpty {
                        Text(verbatim: "κλέβω = to steal\nη κλοπή = theft\nο κλέφτης = thief")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(Text("Lesson words"))
        } footer: {
            Text("One word per line: the Greek word, an equals sign or a dash, then the translation.")
        }

        if !preview.invalidLines.isEmpty {
            Section {
                Label {
                    Text("\(preview.invalidLines.count) lines without a word and a translation are left out.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                ForEach(preview.invalidLines.prefix(Self.invalidLinesShown), id: \.number) { line in
                    LabeledContent("Line \(line.number)") {
                        Text(line.text)
                    }
                    .font(.subheadline)
                }
                if preview.invalidLines.count > Self.invalidLinesShown {
                    Text("and \(preview.invalidLines.count - Self.invalidLinesShown) more")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            if preview.rows.isEmpty {
                Text("Type a word and its translation to see its cards.")
                    .foregroundStyle(.secondary)
            }
            ForEach(preview.rows) { row in
                PreviewRow(row: row, isSelected: isSelected(row)) {
                    if !flipped.insert(row.id).inserted { flipped.remove(row.id) }
                }
            }
        } header: {
            Text("Preview")
        } footer: {
            if !preview.rows.isEmpty {
                Text("The production card unlocks after the recognition card is learned")
            }
        }
    }

    private static let invalidLinesShown = 5

    // MARK: Adding

    @ViewBuilder
    private var addButton: some View {
        let cards = mode == .fromList ? selectedCards(of: preview).count : 0
        Button(action: add) {
            Group {
                if mode == .oneCard {
                    Text("Add")
                } else {
                    Text("Add \(cards) Cards")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .padding(.horizontal, Spacing.margin)
        .padding(.bottom, Spacing.tight)
        .disabled(!document.isReadyToEdit || (mode == .oneCard ? text == nil : cards == 0))
    }

    private func add() {
        switch mode {
        case .oneCard: addOne()
        case .fromList: addList()
        }
    }

    /// Adds the card of the fields, or two if both directions are on, and gets the fields
    /// ready for the next.
    private func addOne() {
        guard let text else {
            focus = CardText.trimmed(question).isEmpty ? .question : .answer
            return
        }
        let count = Self.add(text, bothDirections: bothDirections, to: document)
        // Keeps the fields while the document can't be changed.
        guard count > 0 else { return }
        question = ""
        answer = ""
        hint = ""
        focus = .question
        didAdd(count)
    }

    /// Adds the card of `text`, or its two directions, see `WordPair`, as one undo step.
    /// Returns the number of cards added, 0 while the document can't be changed.
    static func add(_ text: CardText, bothDirections: Bool, to document: VocabularyDocument) -> Int {
        if bothDirections {
            return document.add(WordPair.cards(for: text, created: document.clock.now))
        }
        return document.add(text) == nil ? 0 : 1
    }

    private func addList() {
        let count = document.addLessonCards(selectedCards(of: preview))
        guard count > 0 else { return }
        listText = ""
        flipped = []
        didAdd(count)
    }

    private func didAdd(_ count: Int) {
        addedInSession += count
        additions += 1
        showsConfirmation = true
        AccessibilityNotification.Announcement(String(localized: "Added · \(addedInSession) cards so far")).post()
    }

    // MARK: Leaving

    private func cancel() {
        if hasTypedText {
            asksToDiscard = true
        } else {
            dismiss()
        }
    }

    private func done() {
        switch mode {
        case .oneCard: if text != nil { addOne() }
        case .fromList: if !selectedCards(of: preview).isEmpty { addList() }
        }
        dismiss()
    }
}

/// "Added", with the cards of the sheet's session so far, briefly under the bar.
private struct ConfirmationBadge: View {
    var count: Int

    var body: some View {
        Label("Added · \(count) cards so far", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.tight)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, Spacing.tight)
    }
}

/// One word of the preview: checked to be added, with what is wrong with it, if anything.
private struct PreviewRow: View {
    var row: WordListPreview.Row
    var isSelected: Bool
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.gap) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.entry.greek)
                    Text(row.entry.translation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let duplicate = row.duplicate {
                        Label {
                            switch duplicate {
                            case .inDeck:
                                Text("Already in this deck")
                            case let .inFile(question, answer):
                                Text("Already earlier in the list: \(question) → \(answer)")
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Words

/// The two cards of one word typed on the form of One Card, as Lesson Words makes them:
/// recognition (the Greek asks) and production (the translation asks), with the word key
/// they share, so the deck holds production back until recognition is learned.
enum WordPair {
    /// The cards of `text`, recognition first. The Greek side asks in recognition,
    /// whichever side was typed as the question; the hint goes on both cards.
    static func cards(for text: CardText, created: Date) -> [Card] {
        var greek = text.question
        var translation = text.answer
        if !greek.hasGreekLetters, translation.hasGreekLetters {
            swap(&greek, &translation)
        }
        var note = LessonWords.note(forGreek: greek)
        if note.isEmpty { note = greek }
        guard let recognition = CardText(question: greek, answer: translation, hint: text.hint),
            let production = CardText(question: translation, answer: greek, hint: text.hint)
        else { return [] }
        return [
            Card(text: recognition, note: note, kind: .recognition, created: created),
            Card(text: production, note: note, kind: .production, created: created),
        ]
    }
}

/// What the lines of the From a List mode make: a row per word with its two cards, and
/// the lines that are no word. A word the deck has already, or an earlier line made, stays
/// in the list as a duplicate, unchecked by default, as the import preview does.
struct WordListPreview {
    struct Row: Identifiable {
        /// The word key, numbered if an earlier line has it too.
        var id: String
        var entry: LessonWords.Entry
        /// Recognition, then production.
        var cards: [Card]
        var duplicate: CardImporter.Duplicate?

        var isSelectedByDefault: Bool { duplicate == nil }
    }

    var rows: [Row] = []
    /// The lines with text but no "word = translation": their number, from 1, and text.
    var invalidLines: [(number: Int, text: String)] = []

    init(text: String, deck: Deck, created: Date) {
        let parsed = LessonWords.parse(text)
        let lines = text.components(separatedBy: .newlines)
        invalidLines = parsed.invalidLines.map { ($0, CardText.trimmed(lines[$0 - 1])) }

        // The same keys as the deck's own checks: a word key as `LessonWords.plan`
        // compares them, a question as `CardText.key(forQuestion:)` does.
        let notesInDeck = Set(deck.cards.compactMap(\.note).map(Self.normalized))
        let questionsInDeck = Set(deck.cards.map { CardText.key(forQuestion: $0.question) })
        var firstOfNote: [String: LessonWords.Entry] = [:]
        var linesOfNote: [String: Int] = [:]
        for entry in parsed.entries {
            let key = Self.normalized(entry.note)
            let duplicate: CardImporter.Duplicate? =
                if notesInDeck.contains(key) || questionsInDeck.contains(CardText.key(forQuestion: entry.greek)) {
                    .inDeck
                } else {
                    firstOfNote[key].map { .inFile(question: $0.greek, answer: $0.translation) }
                }
            firstOfNote[key] = firstOfNote[key] ?? entry
            let number = linesOfNote[key, default: 0] + 1
            linesOfNote[key] = number
            let cards = LessonWords.plan(for: [entry], existingNotes: [String](), created: created).cards
            rows.append(Row(id: number == 1 ? key : "\(key)#\(number)", entry: entry, cards: cards, duplicate: duplicate))
        }
    }

    /// Word keys compare in composed Unicode form, as `LessonWords` does.
    private static func normalized(_ note: String) -> String {
        CardText.trimmed(note).precomposedStringWithCanonicalMapping
    }
}

extension String {
    /// Whether the text has Greek letters, of the modern alphabet or the polytonic one.
    fileprivate var hasGreekLetters: Bool {
        unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x1F00...0x1FFF).contains($0.value) }
    }
}
