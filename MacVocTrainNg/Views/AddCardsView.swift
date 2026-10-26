import SwiftUI
import VocabCore

/// "Add Cards…" (⇧⌘L): one sheet with two ways in, as the iPhone's. One Card has Question, Answer and
/// Hint, and Add keeps the sheet open for the next card; From a List takes the lines "word = translation"
/// of a lesson, with a preview of the cards, two for each word. A word another open deck has, or the deck,
/// or an earlier line, is listed unchecked. Every addition is one undo step of the document.
///
/// The sheet opens on the way used last. Done adds what is typed, if it can be added, and closes; Cancel
/// closes without it and asks first if something is typed.
struct AddCardsView: View {
    enum Mode: String {
        case oneCard, fromList
    }

    private enum Field: Hashable {
        case question, answer, hint, list
    }

    @ObservedObject var document: VocabularyDocument
    /// Called with the number of cards added since the sheet opened, when it closes with some.
    var onAdded: (Int) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    /// The words of the other open decks, once they are read.
    @State private var elsewhere = WordIndex()

    /// The way cards were added last time (`modeKey`): someone who adds the week's list comes back to the list.
    @State private var mode: Mode
    static let modeKey = "AddCardsMode"
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
    /// Counts Return presses in the hint field; `onChange` adds. SwiftUI on macOS renews a field's submit
    /// action only when the field's text changes, so Return in a hint field that stayed empty runs the
    /// action of the first render; setting state works from any copy of the view, `onChange` runs the current one.
    @State private var submitRequests = 0

    /// - Parameters: `mode` is the way to open on, the one used last by default; the rest is what the sheet
    ///   starts with, for a test or a snapshot.
    init(document: VocabularyDocument, mode: Mode? = nil, question: String = "", answer: String = "", hint: String = "", list: String = "", added: Int = 0, onAdded: @escaping (Int) -> Void = { _ in }) {
        self.document = document
        self.onAdded = onAdded
        let last = UserDefaults.standard.string(forKey: Self.modeKey).flatMap(Mode.init(rawValue:))
        _mode = State(initialValue: mode ?? last ?? .oneCard)
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
        WordListPreview(text: listText, deck: document.deck, elsewhere: elsewhere, created: document.clock.now)
    }

    /// What another deck holds of the word typed in One Card, on whichever side it is.
    private var otherDeckHit: WordIndex.Hit? {
        [question, answer].lazy.compactMap { WordKey($0) }.compactMap(elsewhere.match).first
    }

    private func isSelected(_ row: WordListPreview.Row) -> Bool {
        row.isSelectedByDefault != flipped.contains(row.id)
    }

    /// What Add would do now, the cards of the checked rows: every recognition card first, then every production card.
    private func selectedCards(of preview: WordListPreview) -> [Card] {
        let cards = preview.rows.filter(isSelected).flatMap(\.cards)
        return cards.filter { $0.kind != .production } + cards.filter { $0.kind == .production }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add Cards")
                    .font(.title2.weight(.semibold))
                Picker("Add Cards", selection: $mode) {
                    Text("One Card").tag(Mode.oneCard)
                    Text("From a List").tag(Mode.fromList)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: mode) {
                    UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
                    focus = mode == .oneCard ? .question : .list
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 4)

            Form {
                switch mode {
                case .oneCard: oneCard
                case .fromList: fromList
                }
            }
            .formStyle(.grouped)

            Divider()

            buttons
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 440, idealHeight: 560)
        .defaultFocus($focus, mode == .oneCard ? .question : .list)
        .task { elsewhere = await OpenDecks.shared.wordIndex(excluding: document) }
        .task(id: additions) {
            guard showsConfirmation else { return }
            try? await Task.sleep(for: .seconds(2))
            showsConfirmation = false
        }
        .animation(.snappy, value: showsConfirmation)
        .confirmationDialog("Discard what you typed?", isPresented: $asksToDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        }
    }

    // MARK: One card

    @ViewBuilder
    private var oneCard: some View {
        Section {
            TextField("Question", text: $question)
                .focused($focus, equals: .question)
                .onSubmit { focus = .answer }
            TextField("Answer", text: $answer)
                .focused($focus, equals: .answer)
                .onSubmit { focus = .hint }
            TextField("Hint", text: $hint, prompt: Text("Hint (optional)"))
                .focused($focus, equals: .hint)
                .onSubmit { submitRequests += 1 }
                .onChange(of: submitRequests) { addOne() }
        } footer: {
            let duplicate = document.deck.cards(withQuestion: question).first
            let hit = otherDeckHit
            if duplicate != nil || hit != nil {
                VStack(alignment: .leading, spacing: Spacing.hairline) {
                    if let duplicate {
                        Label {
                            Text("Already in this deck: \(duplicate.question) → \(duplicate.answer)")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                    switch hit {
                    case let .same(match)?:
                        Label {
                            Text(match.alsoInLine)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    case let .looksLike(match)?:
                        Label {
                            Text(match.similarLine)
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                    case nil:
                        EmptyView()
                    }
                }
            }
        }

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
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .overlay(alignment: .topLeading) {
                    if listText.isEmpty {
                        Text(verbatim: "κλέβω = to steal\nη κλοπή = theft\nο κλέφτης = thief")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(Text("Lesson words"))
        } footer: {
            Text("One word per line: the Greek word, an equals sign, a dash or a hyphen with spaces around it, then the translation.")
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
                WordListRow(row: row, isSelected: isSelected(row)) {
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

    // MARK: Adding and leaving

    private var buttons: some View {
        let cards = mode == .fromList ? selectedCards(of: preview).count : 0
        return HStack {
            if showsConfirmation {
                ConfirmationBadge(count: addedInSession)
                    .transition(.opacity)
            }
            Spacer()
            Button("Cancel", role: .cancel, action: cancel)
                .keyboardShortcut(.cancelAction)
            Button(action: add) {
                if mode == .oneCard {
                    Text("Add")
                } else {
                    Text("Add \(cards) Cards")
                }
            }
            // Return belongs to the fields and the list; ⌘Return adds.
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!document.isReadyToEdit || (mode == .oneCard ? text == nil : cards == 0))
            Button("Done", action: done)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func add() {
        switch mode {
        case .oneCard: addOne()
        case .fromList: addList()
        }
    }

    /// Adds the card of the fields, or two if both directions are on, and gets the fields ready for the next.
    private func addOne() {
        guard let text else {
            focus = CardText.trimmed(question).isEmpty ? .question : .answer
            return
        }
        let count = document.addCards(for: text, bothDirections: bothDirections)
        // Keeps the fields while the document can't be changed.
        guard count > 0 else { return }
        question = ""
        answer = ""
        hint = ""
        focus = .question
        didAdd(count)
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

    private func cancel() {
        if hasTypedText {
            asksToDiscard = true
        } else {
            close()
        }
    }

    private func done() {
        switch mode {
        case .oneCard: if text != nil { addOne() }
        case .fromList: if !selectedCards(of: preview).isEmpty { addList() }
        }
        close()
    }

    private func close() {
        dismiss()
        if addedInSession > 0 {
            onAdded(addedInSession)
        }
    }
}
