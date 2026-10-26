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
    private enum Mode: String {
        case oneCard, fromList
    }

    private enum Field: Hashable {
        case question, answer, hint, list
    }

    @ObservedObject var document: VocabularyDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.knownDeckFiles) private var knownDeckFiles
    /// The words of the other decks, once they are read: a word one of them has is left out of the
    /// list by default, and a typed one is told of.
    @State private var elsewhere = WordIndex()

    /// The way cards were added last time (`modeKey`): someone who adds the week's list comes back to the list.
    @State private var mode: Mode
    private static let modeKey = "AddCardsMode"
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
        let last = GreekSpeech.isUnderTest ? nil : UserDefaults.standard.string(forKey: Self.modeKey).flatMap(Mode.init(rawValue:))
        _mode = State(initialValue: showsList ? .fromList : last ?? .oneCard)
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

    /// What another deck holds of the word typed in One Card, on whichever side the Greek is.
    private var otherDeckHit: WordIndex.Hit? {
        guard let greek = [question, answer].first(where: \.hasGreekLetters), let key = WordKey(greek) else { return nil }
        return elsewhere.match(key)
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
                    .onChange(of: mode) { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
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
        .task { elsewhere = await knownDeckFiles.wordIndex(excluding: document.packageURL) }
    }

    // MARK: One card

    @ViewBuilder
    private var oneCard: some View {
        Section {
            TextField("Question", text: $question)
                .focused($focus, equals: .question)
                .submitLabel(.next)
                .onSubmit { focus = .answer }
            TextField("Answer", text: $answer)
                .focused($focus, equals: .answer)
                .submitLabel(.next)
                .onSubmit { focus = .hint }
            TextField("Hint", text: $hint, prompt: Text("Hint (optional)"))
                .focused($focus, equals: .hint)
                .submitLabel(.done)
                .onSubmit(addOne)
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
