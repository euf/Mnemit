import Foundation
import SwiftUI
import Testing
import UIKit
import os

@testable import VocTrain
@testable import VocabCore

/// The probe for the stutter of the Greek speech: it measures how long the main thread stands
/// still while a card speaks, on a deck the size of the owner's, with what runs after a grade: the
/// document's save, the daily ring, the widget and the screen's own redraws. The speech windows are
/// 0.3 s to 2.0 s after a grade that brings a card with a Greek question (it speaks after
/// `GreekSpeech.settleDelay`, and a slow word lasts until the end of the window), and 0.25 s to
/// 0.9 s after a Greek answer shows. The stream at rest says nothing; its rows are in the report
/// and not in the limit.
///
/// Off unless `MNEMIT_PERF` is set (`TEST_RUNNER_MNEMIT_PERF=1` for `xcodebuild`; `report` only
/// reports and doesn't fail on a stall): it takes a minute, and the owner's deck must be there: a
/// copy of `Greek A1–A2.mnemit` and of the deck next to it goes to a temporary folder; the
/// originals are only read. The report goes to the output and to `STALL_REPORT` (a file path,
/// `TEST_RUNNER_STALL_REPORT`) if set.
///
/// A main-queue timer fires every 5 ms; the gap between two fires is a stall. What ran meanwhile
/// comes from `StallTrace`. The speech itself is off, as in every test, and counts as lasting
/// `simulatedSpeech`. A simulator is faster than the iPhone 13 mini and a Debug build slower than the
/// Release the owner runs; the simulator also waits for Metal on the main thread, so the redraws
/// are longer than they would be. The numbers say which work is the long one, and a Release run
/// gets nearer to the device. A busy Mac shows in them: the report has its load average.
@MainActor @Suite(.serialized, .timeLimit(.minutes(10)))
struct SpeechWindowStallTests {
    /// How long the learner looks at a card before the answer shows, and before the grade.
    static let revealAfter = 1.6
    static let gradeAfter = 2.6
    static let grades = 15
    /// The speech window, in seconds after a grade; and after the answer shows, which is spoken
    /// `GreekSpeech.revealDelay` after, until the grade 1 s later (a little earlier: the swipe starts).
    static let window = 0.3...2.0
    static let answerWindow = GreekSpeech.revealDelay...0.9
    /// A gap this long drops a frame at 60 Hz.
    static let budgetMs = 16.0
    /// How long the voice, which is off, counts as speaking a word: from 0.4 s after the card came up
    /// to the end of the window, a slow word on a good voice.
    static let simulatedSpeech = Duration.milliseconds(1600)

    @Test(.enabled(if: ProcessInfo.processInfo.environment["MNEMIT_PERF"] != nil))
    func theMainThreadDoesNotStandStillWhileTheCardSpeaks() async throws {
        try #require(GreekSpeech.isUnderTest, "a test run must not speak")
        GreekSpeech.shared.autoSpeaks = { true }
        // A Greek word takes about a second to say; the voice is silent, and the work that waits for it
        // waits as it would.
        GreekSpeech.shared.simulatedSpeechDuration = Self.simulatedSpeech
        defer {
            GreekSpeech.shared.autoSpeaks = { GreekSpeech.autoSpeak }
            GreekSpeech.shared.simulatedSpeechDuration = nil
        }
        guard let source = Self.ownerDecks() else {
            print("SKIPPED: the owner's deck is not at ~/Library/Mobile Documents/com~apple~CloudDocs/Mnemit/Greek A1–A2.mnemit")
            return
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var copies: [URL] = []
        for deck in source {
            let copy = folder.appending(path: deck.lastPathComponent, directoryHint: .isDirectory)
            try FileManager.default.copyItem(at: deck, to: copy)
            copies.append(copy)
        }
        let deckURL = copies[0]
        let others = Array(copies.dropFirst())

        let recorder = StallRecorder()
        let report = ReportWriter()
        let openDeck = OpenDeck(url: deckURL)
        let document = try await waitForDocument(of: openDeck)
        report.line("deck: \(document.deck.cards.count) cards, \(others.count) other deck(s); \(Self.configuration); load average \(Self.loadAverage)")
        try await isolatedCosts(of: document, report: report)

        // What the screens do when the stream opens: the ring over all decks, then the stream.
        let ring = DailyRingModel()
        await ring.refresh(documents: [document], files: others, reloadFiles: true, delay: .zero).value
        let model = StudyModel(document: document, rounds: RoundGuide(progress: ring.progress, document: document))
        let widget = WidgetSync(store: FakeSnapshotStore(), isEnabled: true, reload: {})
        let flight = CardFlight()
        let window = try await host(
            ProbeStream(
                document: document, model: model, ring: ring, flight: flight, others: others,
                widgetInputs: { Self.widgetInputs(ring: ring, document: document, others: others) }, widget: widget))
        defer { window.isHidden = true }
        // Lets the first card settle: the redraws of the opening are not what is measured.
        try await Task.sleep(for: .seconds(3))

        StallTrace.sink = { recorder.add($0, $1, $2) }
        defer { StallTrace.sink = nil }
        let timer = GapTimer()
        timer.start()
        defer { timer.stop() }

        var grades: [GradeRecord] = []
        let speech = GreekSpeech.shared
        let pattern: [Grade] = [.good, .easy, .good, .hard, .good, .again, .easy, .good]
        var graded = 0
        while graded < Self.grades {
            var askedBefore = 0
            var spokenBefore = 0
            var record: GradeRecord
            if model.isResting {
                askedBefore = speech.cardAppearedCount
                spokenBefore = speech.speakCount
                // The learner looks at the rest for a moment, then goes on, as the button does.
                try await Task.sleep(for: .seconds(1.5))
                record = GradeRecord(index: grades.count + 1, label: "next")
                record.at = DispatchTime.now().uptimeNanoseconds
                if model.isRoundRest { model.continueRound() } else { model.keepGoing() }
            } else {
                let cardStart = DispatchTime.now().uptimeNanoseconds
                try await Self.sleep(until: cardStart, plus: Self.revealAfter)
                let spokenBeforeReveal = speech.speakCount
                let revealAt = DispatchTime.now().uptimeNanoseconds
                recorder.add("reveal", revealAt, revealAt)
                model.reveal()
                try await Self.sleep(until: cardStart, plus: Self.gradeAfter)
                let grade = pattern[graded % pattern.count]
                graded += 1
                askedBefore = speech.cardAppearedCount
                spokenBefore = speech.speakCount
                record = GradeRecord(index: grades.count + 1, label: "\(grade)")
                record.revealAt = revealAt
                record.speakAtReveal = speech.speakCount - spokenBeforeReveal
                // As the card's `commit` does: the speech stops, the card flies, then the stream grades.
                speech.stop()
                recorder.add("fly", DispatchTime.now().uptimeNanoseconds, DispatchTime.now().uptimeNanoseconds)
                var done = false
                flight.fly(grade, reduceMotion: false) {
                    record.at = DispatchTime.now().uptimeNanoseconds
                    model.grade(grade)
                    record.rested = model.isResting
                    done = true
                }
                try await waitUntil("the card has been graded") { done }
            }
            // The counts are read when the card has settled.
            try await Task.sleep(for: .seconds(0.5))
            record.cardAppeared = speech.cardAppearedCount - askedBefore
            record.speakCalls = speech.speakCount - spokenBefore
            grades.append(record)
        }
        // Nothing more is graded: the save of the merger and the widget come by themselves.
        try await Task.sleep(for: .seconds(8))
        timer.stop()

        let events = recorder.events
        report.table(grades: grades, samples: timer.samples, events: events)
        report.line("load average at the end: \(Self.loadAverage) (other work on the Mac shows in the stalls)")
        report.line("keychain write (real store, main thread, once): \(Self.keychainWriteMs(document: document, ring: ring))")
        try report.write()
        await openDeck.close()
        let worst = Self.worstStalls(grades, samples: timer.samples)
        if ProcessInfo.processInfo.environment["MNEMIT_PERF"] != "report" {
            #expect(worst.question < Self.budgetMs, "the longest stall in the speech window of a question is \(worst.question) ms")
            #expect(worst.answer < Self.budgetMs, "the longest stall in the speech window of an answer is \(worst.answer) ms")
        }
    }

    /// The study screen asks the voice for a card when `questionNumber` changes (`StudyView`), so a
    /// card asks once if the number grows once with every move to it: a second ask for the same card
    /// cuts its speech off and starts it again, which sounds like a stutter as well. A grade, Undo
    /// and Redo each move once.
    @Test func everyMoveToACardCountsOnce() throws {
        let created = Date(timeIntervalSince1970: 1_791_216_000)
        let cards = ["το σπίτι", "ο δρόμος", "η θάλασσα", "το βιβλίο"].map { Card(text: CardText(question: $0, answer: "x")!, created: created) }
        let document = try VocabularyDocument(deck: Deck(cards: cards), clock: StudyClock { created.addingTimeInterval(60) })
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.attachUndoManager(undoManager)
        let model = StudyModel(document: document)
        #expect(model.questionNumber == 0)

        for grade in 1...3 {
            model.reveal()
            undoManager.beginUndoGrouping()
            model.grade(.good)
            undoManager.endUndoGrouping()
            #expect(model.questionNumber == grade)
        }
        undoManager.undo()
        #expect(model.questionNumber == 4)
        undoManager.redo()
        #expect(model.questionNumber == 5)
    }

    // MARK: - The deck

    /// The owner's decks, the one the probe studies first, or `nil` if the Mac has none at hand.
    static func ownerDecks() -> [URL]? {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return nil }
        let folder = URL(fileURLWithPath: home).appending(path: "Library/Mobile Documents/com~apple~CloudDocs/Mnemit", directoryHint: .isDirectory)
        let main = folder.appending(path: "Greek A1–A2.mnemit", directoryHint: .isDirectory)
        guard FileManager.default.isReadableFile(atPath: main.appending(path: "deck.json").path) else { return nil }
        let rest = ["Greek B1.mnemit"].map { folder.appending(path: $0, directoryHint: .isDirectory) }
            .filter { FileManager.default.isReadableFile(atPath: $0.appending(path: "deck.json").path) }
        return [main] + rest
    }

    /// The Mac's load over the last minute and five: a busy machine makes every stall longer.
    static var loadAverage: String {
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        return String(format: "%.1f / %.1f", load[0], load[1])
    }

    static var configuration: String {
        #if DEBUG
        "Debug build"
        #else
        "Release build"
        #endif
    }

    private func waitForDocument(of deck: OpenDeck) async throws -> VocabularyDocument {
        try await waitUntil("the deck is open") { deck.document != nil && deck.isEditable }
        return try #require(deck.document)
    }

    // MARK: - Wiring

    /// What the screens hand to the widget, as `StartScreen.widgetInputs` does.
    static func widgetInputs(ring: DailyRingModel, document: VocabularyDocument, others: [URL]) -> WidgetSync.Inputs? {
        guard let progress = ring.progress else { return nil }
        let decks: [WidgetSync.Source] =
            [.open(document.deck, document.calendar, allowance: document.newCardAllowance)]
            + others.map { .file($0, allowance: NewCardAllowances.today[$0]) }
        return WidgetSync.Inputs(progress: progress, decks: decks, nextReminder: nil)
    }

    /// The study screen as `DeckStream` wires it (the ring follows every change of the deck) and
    /// as `StartScreen` wires the widget (a new ring asks for a new snapshot).
    private struct ProbeStream: View {
        @ObservedObject var document: VocabularyDocument
        var model: StudyModel
        var ring: DailyRingModel
        var flight: CardFlight
        var others: [URL]
        var widgetInputs: () -> WidgetSync.Inputs?
        var widget: WidgetSync

        var body: some View {
            StudyView(model: model, ring: ring, flight: flight, onClose: {})
                .onReceive(document.deckDidChange) { ring.refresh(documents: [document], files: others) }
                .onChange(of: ring.progress) {
                    if let inputs = widgetInputs() { widget.request(inputs) }
                }
        }
    }

    private func host<Root: View>(_ root: Root) async throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        return window
    }

    private static func sleep(until start: UInt64, plus seconds: Double) async throws {
        let target = start + UInt64(seconds * 1e9)
        let now = DispatchTime.now().uptimeNanoseconds
        if target > now { try await Task.sleep(nanoseconds: target - now) }
    }

    // MARK: - Costs measured one at a time

    /// The work that runs after a grade, run alone on the main thread, five times each: the
    /// median and the largest, in milliseconds.
    private func isolatedCosts(of document: VocabularyDocument, report: ReportWriter) async throws {
        func time(_ name: String, _ work: () throws -> Void) rethrows {
            var runs: [Double] = []
            for _ in 0..<5 {
                let start = DispatchTime.now().uptimeNanoseconds
                try work()
                runs.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
            }
            runs.sort()
            report.line(String(format: "alone  %@ median %7.2f ms   max %7.2f ms", name.padding(toLength: 46, withPad: " ", startingAt: 0), runs[2], runs[4]))
        }
        try time("document.fileWrapper() (the save's encode)") { _ = try document.fileWrapper() }
        time("StudySession.counts (the due counter)") {
            _ = StudySession.counts(for: document.deck, at: document.clock.now, calendar: document.calendar, newCardAllowance: document.newCardAllowance)
        }
        time("RoundGuide.cardsDone(in:)") {
            _ = RoundGuide(ends: [10, 20], doneElsewhere: 3).cardsDone(in: document)
        }
        var size: CGFloat = 150
        time("gradient of a 150 pt ring, made anew (rest screen)") {
            size += 1
            let tip = CGColor(red: 0.6, green: 0.6, blue: 0.95, alpha: 1)
            let accent = CGColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1)
            _ = GradientGenerator.image(
                scale: 3, size: CGSize(width: size, height: size), colors: [tip, tip, accent, accent], locations: [0, 0.05, 0.95, 1], endPoint: CGPoint(x: 0.4, y: 1))
        }
        time("DailyProgress.evaluate (off main in the app)") {
            let activity = DeckActivity(deck: document.deck, calendar: document.calendar)
            _ = DailyProgress.evaluate([activity], at: document.clock.now, calendar: document.calendar)
        }
    }

    /// One write of the widget's snapshot into the real keychain, which the app does on the main
    /// thread; the simulator's keychain is a file, the iPhone's is another process.
    static func keychainWriteMs(document: VocabularyDocument, ring: DailyRingModel) -> String {
        guard let inputs = widgetInputs(ring: ring, document: document, others: []) else { return "no ring" }
        let snapshot = WidgetSync.snapshot(from: inputs, at: Date())
        let store = KeychainSnapshotStore(service: "com.euf.mnemit.stall-probe")
        let start = DispatchTime.now().uptimeNanoseconds
        let stored = store.write(snapshot)
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        store.remove()
        return stored ? String(format: "%.2f ms", ms) : "not possible here (no keychain group), tried \(String(format: "%.2f", ms)) ms"
    }

    /// The longest stalls in the windows where a card speaks: after a grade that brings a card with a
    /// Greek question, and after the answer shows when it is Greek; and, for the record, after any
    /// grade that leaves a card (a stream at rest speaks nothing).
    static func worstStalls(_ grades: [GradeRecord], samples: [GapTimer.Sample]) -> (question: Double, answer: Double, anyGrade: Double) {
        func worst(_ records: [GradeRecord], at time: (GradeRecord) -> UInt64?, range: ClosedRange<Double>) -> Double {
            records.compactMap { record in time(record).map { worstGap(in: samples, around: $0, range: range) } }.max() ?? 0
        }
        let question = grades.filter { !$0.rested && $0.speakCalls > 0 }
        let answer = grades.filter { $0.speakAtReveal > 0 }
        return (
            worst(question, at: \.at, range: window), worst(answer, at: \.revealAt, range: answerWindow),
            worst(grades.filter { !$0.rested }, at: \.at, range: window)
        )
    }

    static func worstGap(in samples: [GapTimer.Sample], around at: UInt64, range: ClosedRange<Double>) -> Double {
        let from = at + UInt64(range.lowerBound * 1e9)
        let to = at + UInt64(range.upperBound * 1e9)
        return samples.filter { $0.end > from && $0.end - $0.gap < to }.map { Double($0.gap) / 1e6 }.max() ?? 0
    }
}

struct GradeRecord {
    var index: Int
    /// The grade given, or `next`: the learner went on from a rest.
    var label: String
    /// When the stream graded, as uptime nanoseconds.
    var at: UInt64?
    var cardAppeared = 0
    var speakCalls = 0
    /// The grade ended a round: the stream rests, no card shows and nothing is spoken.
    var rested = false
    /// When the answer was shown, and how many utterances that asked for (a Greek answer under a
    /// question in Russian is spoken at once).
    var revealAt: UInt64?
    var speakAtReveal = 0
}

/// Collects what `StallTrace` hears, from any thread.
final class StallRecorder: @unchecked Sendable {
    struct Event {
        var name: String
        var start: UInt64
        var end: UInt64
        var milliseconds: Double { Double(end - start) / 1e6 }
    }

    private let lock = OSAllocatedUnfairLock(initialState: [Event]())

    func add(_ name: String, _ start: UInt64, _ end: UInt64) {
        lock.withLock { $0.append(Event(name: name, start: start, end: end)) }
    }

    var events: [Event] { lock.withLock { $0 } }
}

/// A timer on the main queue every 5 ms; how late each fire is says how long the thread stood
/// still.
@MainActor
final class GapTimer {
    struct Sample {
        /// When the fire happened, and how long after the one before, in nanoseconds.
        var end: UInt64
        var gap: UInt64
    }

    private(set) var samples: [Sample] = []
    private var last = DispatchTime.now().uptimeNanoseconds
    private let source = DispatchSource.makeTimerSource(queue: .main)
    private var running = false

    func start() {
        last = DispatchTime.now().uptimeNanoseconds
        source.schedule(deadline: .now() + .milliseconds(5), repeating: .milliseconds(5), leeway: .nanoseconds(0))
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.fire() }
        }
        source.resume()
        running = true
    }

    func stop() {
        guard running else { return }
        running = false
        source.cancel()
    }

    private func fire() {
        let now = DispatchTime.now().uptimeNanoseconds
        samples.append(Sample(end: now, gap: now - last))
        last = now
    }
}

/// The report of the probe: lines to the output, and to a file if `STALL_REPORT` names one.
@MainActor
final class ReportWriter {
    private var lines: [String] = []

    func line(_ text: String) {
        print(text)
        lines.append(text)
    }

    func write() throws {
        guard let path = ProcessInfo.processInfo.environment["STALL_REPORT"] else { return }
        try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// One row per grade: the longest stall in the window of speech, and before it, what ran in the
    /// window and how often the card asked for speech; then the work by name.
    func table(grades: [GradeRecord], samples: [GapTimer.Sample], events: [StallRecorder.Event]) {
        line("")
        line("grade | before 0-0.3 s | window 0.3-2.0 s (at) | asks | speaks | what ran in the window (ms, at s)")
        for grade in grades {
            guard let at = grade.at else { continue }
            let before = SpeechWindowStallTests.worstGap(in: samples, around: at, range: 0...0.3)
            let from = at + UInt64(0.3 * 1e9)
            let to = at + UInt64(2.0 * 1e9)
            let inWindow = samples.filter { $0.end > from && $0.end - $0.gap < to }
            let worst = inWindow.max { $0.gap < $1.gap }
            let worstText = worst.map { String(format: "%6.1f (%.2f s)", Double($0.gap) / 1e6, Double($0.end - at) / 1e9) } ?? "     -"
            let ran = events.filter { $0.end > from && $0.start < to && $0.milliseconds >= 1 && !$0.name.hasSuffix("(off main)") }
                .map { String(format: "%@ %.1f @%.2f", $0.name, $0.milliseconds, Double($0.start) / 1e9 - Double(at) / 1e9) }
                .joined(separator: "; ")
            line(String(format: "%2d %@ | %6.1f | %@ | %d | %d | %@", grade.index, grade.rested ? "\(grade.label) (rest)" : grade.label, before, worstText, grade.cardAppeared, grade.speakCalls, ran))
        }
        line("")
        line("answer shown | max gap 0-0.25 s after (the redraw) | max gap 0.25-0.9 s after (the answer is spoken; the grade comes at 1.0 s) | utterances asked at the reveal")
        for grade in grades {
            guard let at = grade.revealAt else { continue }
            line(
                String(
                    format: "%2d | %6.1f | %6.1f | %d", grade.index, SpeechWindowStallTests.worstGap(in: samples, around: at, range: 0...0.25),
                    SpeechWindowStallTests.worstGap(in: samples, around: at, range: 0.25...0.95), grade.speakAtReveal))
        }
        line("")
        line("work by name over the whole run: count, median, max ms")
        let byName = Dictionary(grouping: events, by: \.name)
        for (name, group) in byName.sorted(by: { $0.key < $1.key }) {
            let times = group.map(\.milliseconds).sorted()
            line(String(format: "  %@ n=%3d  median %7.2f  max %7.2f", name.padding(toLength: 20, withPad: " ", startingAt: 0), times.count, times[times.count / 2], times.last ?? 0))
        }
        let all = samples.map { Double($0.gap) / 1e6 }
        line(String(format: "all gaps of the run: samples %d, over 16 ms %d, max %.1f ms", all.count, all.filter { $0 > 16 }.count, all.max() ?? 0))
        let worst = SpeechWindowStallTests.worstStalls(grades, samples: samples)
        let budget = SpeechWindowStallTests.budgetMs
        line(String(format: "MAX STALL, SPEECH WINDOW OF A QUESTION (0.3-2.0 s after a grade whose card speaks): %.1f ms (budget %.0f ms)", worst.question, budget))
        line(String(format: "MAX STALL, SPEECH WINDOW OF AN ANSWER (0.25-0.9 s after it shows): %.1f ms (budget %.0f ms)", worst.answer, budget))
        line(String(format: "for the record, 0.3-2.0 s after any grade that leaves a card, spoken or not: %.1f ms", worst.anyGrade))
        line("")
        line("stalls over 16 ms outside the windows: where they fall (s after the nearest grade before them)")
        let starts = grades.compactMap(\.at)
        for sample in samples where Double(sample.gap) / 1e6 > 16 {
            let before = starts.last { $0 <= sample.end }
            let offset = before.map { Double(sample.end - $0) / 1e9 } ?? -1
            let named = events.filter {
                $0.end >= sample.end - sample.gap && $0.start <= sample.end && ($0.milliseconds >= 1 || $0.start == $0.end) && !$0.name.hasSuffix("(off main)")
            }
            .map { $0.start == $0.end ? "[\($0.name)]" : String(format: "%@ %.1f", $0.name, $0.milliseconds) }.joined(separator: "; ")
            line(String(format: "  gap %6.1f ms at +%.2f s after grade: %@", Double(sample.gap) / 1e6, offset, named.isEmpty ? "(nothing traced: SwiftUI or the system)" : named))
        }
    }
}
