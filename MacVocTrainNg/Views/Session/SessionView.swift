import SwiftUI
import VocabCore

/// The session screen: asks one card after another.
///
/// Keyboard flow: type the response and press Return. A correct response moves on
/// directly (unless disabled in the preferences). Otherwise the answer is shown
/// and Return accepts the suggested grade; 1–4 choose a grade explicitly, e.g. 3
/// when the response was right after all. ⌘Z takes back the last review.
///
/// With flash cards (the preference "Study by"), there is no response: Space or Return
/// shows the answer, then ← Forgot, → Good, ↑ Easy, ↓ Hard, or 1–4 for Forgot, Hard, Good
/// and Easy, and Space or Return mean Good. The card flies out in the direction of its
/// grade, while the button of the grade flashes. A line under the progress names the grade and when the card comes back, and offers
/// Undo for a few seconds; Z, Esc and ⌘Z take the review back. S speaks the Greek side.
///
/// ⌘E edits the card being asked (#289); before the response is checked or the answer
/// shown, without showing its answer. The response typed so far stays, and a response
/// already checked is checked again against the edited card.
///
/// "Suspend Card", under the arrow of "Edit Card…" (#293), leaves out the card from now
/// on, until the learner resumes it (#290).
struct SessionView: View {
    @Bindable var model: SessionViewModel
    var onClose: () -> Void

    /// The question whose response field has the focus.
    @FocusState private var focusedQuestion: Int?
    @State private var confirmingEnd = false
    @State private var editing: EditRequest?

    /// The card that `CardEditSheet` edits, as it was when the sheet opened, and whether
    /// the sheet hides its answer.
    struct EditRequest: Identifiable {
        var card: Card
        var hidesAnswer: Bool
        var id: Card.ID { card.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.isFinished {
                SessionSummaryView(model: model, onClose: onClose)
            } else if let card = model.currentCard {
                cardArea(card)
            }
            if let previous = model.previous, !model.isFinished {
                Divider()
                PreviousReviewBar(previous: previous)
            }
        }
        .background { keys }
        .confirmationDialog("End this session?", isPresented: $confirmingEnd) {
            if model.session.startedCount > 0 {
                Button("Finish Started Cards (\(model.session.startedCount))") {
                    model.finishUp()
                }
            }
            Button("End Now") { onClose() }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Your reviews so far are saved. Cards you haven't finished stay due.")
        }
        .sheet(item: $editing, onDismiss: focusResponse) { request in
            CardEditSheet(document: model.document, card: request.card, hidesAnswer: request.hidesAnswer)
        }
    }

    /// Edits the card being asked; its answer stays hidden until the response is checked
    /// or, with flash cards, shown.
    private func editCurrentCard() {
        guard let card = model.currentCard else { return }
        editing = EditRequest(card: card, hidesAnswer: model.stage == .asking)
    }

    /// Keys without a button to show: with flash cards, Z and Esc take back the review,
    /// which ⌘Z does too; with S for the speaker button of the card. The keys that grade
    /// belong to `GradeChoice`.
    private var keys: some View {
        Group {
            if model.studyBy == .flashcards {
                Group {
                    Button("Undo", action: model.undoLast)
                        .keyboardShortcut("z", modifiers: [])
                    // Esc undoes instead of ending the session, whose button has no shortcut then.
                    Button("Undo", action: model.undoLast)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .disabled(!model.canUndoLast)
            }
            if let spokenText {
                Button("Pronounce") { GreekSpeech.shared.speak(spokenText) }
                    .keyboardShortcut("s", modifiers: [])
            }
        }
        .hidden()
    }

    /// What S speaks: the question if it is Greek, else the answer once it shows. Not while
    /// a response is typed, as the key would be a letter of it.
    private var spokenText: String? {
        guard let card = model.currentCard, model.studyBy == .flashcards || isAnswerShown else { return nil }
        if GreekSpeech.shared.canSpeak(card.question) { return card.question }
        return isAnswerShown && GreekSpeech.shared.canSpeak(card.answer) ? card.answer : nil
    }

    private var isAnswerShown: Bool {
        switch model.stage {
        case .revealed, .feedback: true
        case .asking, .finished: false
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            let session = model.session
            if model.isPracticing {
                Text("Practice")
                    .font(.headline)
            }
            ProgressView(value: Double(session.completedCount), total: Double(max(session.totalCount, 1)))
                .frame(maxWidth: 320)
            Text("\(session.completedCount) / \(session.totalCount)")
                .monospacedDigit()
            Label("\(session.mistakeIDs.count)", systemImage: "xmark.circle")
                .monospacedDigit()
                .foregroundStyle(session.mistakeIDs.isEmpty ? Color.secondary : Grade.again.color)
                .help("Mistakes")
                .accessibilityLabel(Text("\(session.mistakeIDs.count) mistakes"))
            Spacer()
            if !model.isFinished {
                // A pull-down button: a click edits, the arrow offers Suspend Card.
                Menu("Edit Card…") {
                    Button("Suspend Card") { model.suspendCurrentCard() }
                        .help("Don't ask this card again until you resume it in the card list")
                } primaryAction: {
                    editCurrentCard()
                }
                .fixedSize()
                // On the menu, ⌘E would also show next to its first item, Suspend Card.
                .background {
                    Button("Edit Card…", action: editCurrentCard)
                        .keyboardShortcut("e", modifiers: .command)
                        .hidden()
                }
                .disabled(model.currentCard == nil)
                .help("Fix this card without leaving the session")
                Button("End Session") { confirmingEnd = true }
                    // With flash cards Esc takes back a review, see `keys`.
                    .keyboardShortcut(model.studyBy == .flashcards ? nil : .cancelAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func cardArea(_ card: Card) -> some View {
        VStack(spacing: 12) {
            // Under the progress, in the same place on every card.
            UndoChip(receipt: model.receipt, onUndo: model.undoLast, onExpire: model.dismissReceipt)

            Spacer()

            if model.studyBy == .flashcards {
                FlashcardView(
                    card: card, isRevealed: model.stage == .revealed,
                    onReveal: { model.reveal() }, onGrade: { grade in model.grade(grade) })
            } else {
                typedQuestion(card)
            }

            Spacer()

            CardStateLine(card: card)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The question, the field for the response and, once it is checked, the feedback.
    private func typedQuestion(_ card: Card) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Text(card.question)
                    .font(.system(size: 32, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                SpeakButton(text: card.question)
            }

            if !card.hint.isEmpty {
                Text(card.hint)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Response", text: $model.input, prompt: Text("Response"))
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .focused($focusedQuestion, equals: model.questionNumber)
                .disabled(model.stage != .asking)
                .onSubmit { model.submit() }
                // Before `id`, so it runs for every new field, not only the first.
                .onAppear { focus(model.questionNumber) }
                // A new field per question: with automatic continuing the field never
                // ends editing, and ⌘Z would first take back the previous typing (#9).
                .id(model.questionNumber)

            Group {
                if case let .feedback(result, response) = model.stage {
                    FeedbackView(
                        result: result, response: response, expected: card.answer, highlightedAnswer: model.highlightedAnswer
                    ) { grade in
                        model.grade(grade)
                    }
                } else {
                    Text("Press Return to check your response.")
                        .foregroundStyle(.tertiary)
                }
            }
            // As high as the feedback with its grade buttons, so the question stays put.
            .frame(minHeight: 230, alignment: .top)
        }
    }

    /// Gives the response field the focus back after the edit sheet; the response typed
    /// so far stays.
    private func focusResponse() {
        focus(model.questionNumber)
    }

    /// Focuses the response field of `question` once the current event is handled.
    /// With automatic continuing the new field appears while the previous one is
    /// still ending its editing; focus set right away got lost there (#75).
    private func focus(_ question: Int) {
        Task { @MainActor in
            focusedQuestion = question
        }
    }
}

/// Check result, the answer, and the grade buttons.
private struct FeedbackView: View {
    var result: CheckResult
    var response: String
    var expected: String
    /// The answer with the differences marked, for almost correct responses.
    var highlightedAnswer: [ResponseDiff.Segment]?
    var onGrade: @MainActor (Grade) -> Void

    var body: some View {
        VStack(spacing: 14) {
            // The dot is the colour of the grade Return accepts.
            HStack(spacing: 8) {
                GradeDot(grade: result.suggestedGrade)
                Label(title, systemImage: symbol)
            }
            .font(.title3.weight(.semibold))

            if result != .correct {
                VStack(spacing: 4) {
                    Text("Answer:")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        answerText
                            .font(.title2)
                            .textSelection(.enabled)
                        SpeakButton(text: expected)
                    }
                }
            }

            // Return accepts the suggestion.
            GradeChoice(defaultGrade: result.suggestedGrade, onGrade: onGrade)
                .frame(maxWidth: 440)
        }
    }

    private var title: String {
        switch result {
        case .correct: String(localized: "Correct")
        case .incomplete: String(localized: "Incomplete")
        case .almostCorrect: String(localized: "Almost – check the spelling")
        case .wrong:
            response.trimmingCharacters(in: .whitespaces).isEmpty
                ? String(localized: "No response")
                : String(localized: "Wrong")
        }
    }

    private var symbol: String {
        switch result {
        case .correct: "checkmark.circle.fill"
        case .incomplete: "checkmark.circle"
        case .almostCorrect: "exclamationmark.circle"
        case .wrong: "xmark.circle.fill"
        }
    }

    /// The answer; for almost correct responses with the differences highlighted.
    private var answerText: Text {
        guard let highlightedAnswer else { return Text(expected) }
        return highlightedAnswer.reduce(Text(verbatim: "")) { text, segment in
            if segment.isMismatch {
                return text + Text(segment.text).bold().underline().foregroundColor(Grade.again.color)
            }
            return text + Text(segment.text)
        }
    }
}

/// Flash cards: the card with the question, then the answer under it, and the button that
/// shows the answer or the grade buttons below. The card flies out in the direction of
/// its grade.
private struct FlashcardView: View {
    var card: Card
    var isRevealed: Bool
    var onReveal: () -> Void
    var onGrade: @MainActor (Grade) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flight = CardFlight()

    var body: some View {
        VStack(spacing: 14) {
            FlightCard(flight: flight) {
                face
            }
            .frame(maxWidth: 560, minHeight: 160, idealHeight: 240, maxHeight: 260)
            .contentShape(Rectangle())
            .onTapGesture(perform: onReveal)

            actions
                .frame(maxWidth: 440, minHeight: 104, alignment: .top)
        }
    }

    /// The question above the divider, the answer below it, in the same places whether or
    /// not the answer shows.
    private var face: some View {
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(card.question)
                        .font(.system(size: 32, weight: .semibold))
                        .textSelection(.enabled)
                    SpeakButton(text: card.question)
                }
                if !card.hint.isEmpty {
                    Text(card.hint)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            Group {
                Divider()
                HStack(spacing: 8) {
                    Text(card.answer)
                        .font(.title)
                        .textSelection(.enabled)
                    SpeakButton(text: card.answer)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .opacity(isRevealed ? 1 : 0)
            // The hidden answer has no speaker button to click.
            .allowsHitTesting(isRevealed)
            .accessibilityHidden(!isRevealed)
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.5)
        .padding(20)
    }

    @ViewBuilder
    private var actions: some View {
        if isRevealed {
            // Space and Return showed the answer and now mean Good; the arrows grade as the
            // swipes do on the iPhone.
            GradeChoice(defaultGrade: .good, acceptsSpace: true, acceptsArrows: true, highlighted: flight.highlighted, onGrade: commit)
        } else {
            Button(action: onReveal) {
                VStack(spacing: 2) {
                    Text("Show Answer")
                    Text("Space or ↩")
                        .font(.caption)
                }
                .frame(minWidth: 120)
                .padding(.vertical, 2)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)

            // A button takes one shortcut; Space shows the answer too.
            Button(action: onReveal) {
                Text(verbatim: "")
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    /// Flies the card out in the direction of `grade`, then grades. Keys, buttons and
    /// VoiceOver all come here, so a second key press while the card flies does nothing.
    private func commit(_ grade: Grade) {
        guard isRevealed, !flight.isFlying else { return }
        flight.fly(grade, reduceMotion: reduceMotion) { onGrade(grade) }
    }
}

/// Small line telling where the current card stands.
private struct CardStateLine: View {
    var card: Card

    var body: some View {
        Group {
            if let learningState = card.learningState {
                switch learningState.phase {
                case .review:
                    Text("Review phase · remembered for \(Format.days(learningState.stability))")
                case .learning:
                    Text("Learning")
                case .relearning:
                    Text("Relearning")
                }
            } else {
                Text("New card")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

private struct PreviousReviewBar: View {
    var previous: SessionViewModel.PreviousReview

    var body: some View {
        HStack(spacing: 8) {
            Text("Previous:")
                .foregroundStyle(.secondary)
            Text("\(previous.question) → \(previous.answer)")
                .lineLimit(1)
            if let grade = previous.grade {
                GradeDot(grade: grade)
                Text(grade.title)
            } else {
                Text("Suspended")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("⌘Z to undo")
                .foregroundStyle(.tertiary)
        }
        .font(.callout)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
