import AVFoundation
import SwiftUI
import VocabCore

extension String {
    /// Whether the text has Greek letters, of the modern alphabet or the polytonic one.
    var containsGreek: Bool {
        unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x1F00...0x1FFF).contains($0.value) }
    }
}

/// Speaks Greek text with a voice installed on the device, for the speaker button, the
/// Mac's S key and, if the learner wants it, by itself (`autoSpeak`).
///
/// One synthesizer and one audio session for the whole stream, set up when the stream opens
/// (`open()`) and let go of when it closes (`close()`), so an utterance never waits for the
/// audio hardware or for a change of category. The speech the stream asks for by itself
/// starts only once a card has settled: `cardAppeared(_:)` waits `settleDelay`, an answer
/// that shows waits `revealDelay`, and a card that leaves before that never speaks.
///
/// While a card is about to speak or speaks, the main thread and the processor are the
/// voice's: what can wait does (`whenQuiet()`): the daily ring that follows a grade, the save
/// of the deck, the widget's snapshot.
@MainActor
final class GreekSpeech {
    static let shared = GreekSpeech()

    /// The preference "Speak Greek automatically": a card speaks its Greek side by itself.
    nonisolated static let autoSpeakKey = "speakGreekAutomatically"

    /// On until the learner turns it off.
    nonisolated static var autoSpeak: Bool {
        UserDefaults.standard.object(forKey: autoSpeakKey) as? Bool ?? true
    }

    /// How long a card has been on screen before it speaks by itself, in seconds: after its
    /// appear animation (about 0.25 s; the first card's cover takes a little longer) and the
    /// fly-out of the one before (`CardFlight.duration`) have ended. Speech started in the
    /// middle of them competes with the animation for the main thread and stutters.
    static let settleDelay = 0.4
    /// The same for an answer that shows: its redraw (up to 80 ms in the stall probe) is over
    /// before the voice starts.
    static let revealDelay = 0.25
    /// The longest `whenQuiet()` waits: a speech that doesn't report its end holds nothing up for
    /// longer.
    static let quietLimit = Duration.seconds(4)
    /// A short silence before every utterance: the audio route is up by the time the first
    /// syllable plays, which otherwise loses its start.
    private static let preUtteranceDelay = 0.05

    /// Whether the process is a test run. A test never speaks and never touches the audio
    /// session, whatever it shows: the simulator plays through the speakers of the Mac.
    nonisolated static let isUnderTest: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
            || Bundle.allBundles.contains { $0.bundlePath.hasSuffix(".xctest") }
    }()

    /// The best voice for Greek the device has, premium before enhanced before default; `nil`
    /// without one, and the speaker buttons stay hidden. Looked up once, when the first
    /// stream opens, and kept: a voice installed meanwhile shows after a restart.
    let voice: AVSpeechSynthesisVoice? = GreekSpeech.bestVoice()

    /// What was asked of the speech, kept in a test run only, where nothing is spoken: a card that
    /// came up and an utterance. A second ask for the same card cuts the first speech off and
    /// starts it again, which sounds like a stutter.
    enum Request: Equatable {
        case cardAppeared(Card.ID?)
        case speak(String)
    }

    private(set) var requests: [Request] = []

    var cardAppearedCount: Int { requests.count { if case .cardAppeared = $0 { true } else { false } } }
    var speakCount: Int { requests.count { if case .speak = $0 { true } else { false } } }

    /// Whether a card speaks by itself, asked when it does: the preference. A test has its own answer,
    /// as the preference is read by every test that runs.
    var autoSpeaks: () -> Bool = { GreekSpeech.autoSpeak }

    /// For a test, which never speaks: how long a speech counts as lasting, so that what waits
    /// for the quiet does wait. `nil`, and then a test run is never busy.
    var simulatedSpeechDuration: Duration?

    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = Delegate()
    /// The utterance that is said now or waits to be said.
    private var current: AVSpeechUtterance?
    private var simulatedEnd: Task<Void, Never>?
    /// The speech a card asked for by itself and that waits for the card to settle.
    private var pending: Task<Void, Never>?
    private var isOpen = false
    /// Whether an utterance is said now or on its way to be.
    private(set) var isSpeaking = false

    /// Whether the voice is, or is about to be, at work: a card waits for its settle time to speak,
    /// or an utterance is said. A test run is never busy unless it simulates speech.
    var isBusy: Bool {
        (!Self.isUnderTest || simulatedSpeechDuration != nil) && (pending != nil || isSpeaking)
    }

    /// Not private, for the tests that need a voice of their own; the app uses `shared`.
    init() {
        synthesizer.delegate = delegate
        delegate.ended = { [weak self] id in self?.speechEnded(id) }
        #if os(iOS)
        // A call or an alarm ends the audio session; the stream that is open takes it back.
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.ended.rawValue else { return }
            Task { @MainActor in
                if GreekSpeech.shared.isOpen {
                    GreekSpeech.shared.activateSession(thenWarmUp: false)
                }
            }
        }
        #endif
    }

    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "el-GR" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }

    /// Whether `text` can be spoken: it is Greek, and a voice is there. A test run counts as
    /// having one, so what shows with a speaker button shows the same on a machine without a
    /// Greek voice; it still says nothing (`speak(_:)`).
    func canSpeak(_ text: String) -> Bool {
        (voice != nil || Self.isUnderTest) && text.containsGreek
    }

    /// Prepares speaking for a stream that opens: the audio session, once, and the voice, which
    /// a first silent utterance loads. Does nothing without a Greek voice, and when already open.
    func open() {
        guard !Self.isUnderTest, voice != nil, !isOpen else { return }
        isOpen = true
        #if os(iOS)
        activateSession(thenWarmUp: true)
        #else
        warmUp()
        #endif
    }

    /// The stream closes: stops what is said and hands the audio session back, so the other
    /// audio of the device goes on.
    func close() {
        stop()
        guard isOpen else { return }
        isOpen = false
        #if os(iOS)
        DispatchQueue.global(qos: .utility).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }

    /// A silent utterance, so the voice is loaded before the first real one.
    private func warmUp() {
        let utterance = AVSpeechUtterance(string: "ναι")
        utterance.voice = voice
        utterance.volume = 0
        current = utterance
        synthesizer.speak(utterance)
    }

    #if os(iOS)
    /// Configures and activates the shared audio session, once per stream. Off the main
    /// thread: activating blocks until the hardware answers. Played even with the ringer
    /// switch on silent, as the learner asked for it; mixed with what else plays, so opening
    /// the stream doesn't stop the learner's music or podcast.
    private func activateSession(thenWarmUp: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try? session.setActive(true)
            if thenWarmUp {
                Task { @MainActor in GreekSpeech.shared.warmUp() }
            }
        }
    }
    #endif

    /// Speaks the head word of `text`: what comes before the first bracket or comma, so
    /// "χαλάω (χάλασα)" and "υπεύθυνος, -η, -ο" don't read out their forms, nor the example
    /// sentence under an answer. What is still being spoken is cut off, and nothing else is
    /// stopped or started around it.
    func speak(_ text: String) {
        let word = text.prefix { $0 != "(" && $0 != "," && !$0.isNewline }.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }
        pending?.cancel()
        pending = nil
        if Self.isUnderTest {
            requests.append(.speak(word))
            if let duration = simulatedSpeechDuration { simulateSpeech(for: duration) }
            return
        }
        guard let voice else { return }
        cutOff()
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        utterance.preUtteranceDelay = Self.preUtteranceDelay
        current = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Cuts off what is being said and what waits to be said.
    func stop() {
        pending?.cancel()
        pending = nil
        simulatedEnd?.cancel()
        isSpeaking = false
        cutOff()
    }

    /// Stops the utterance in flight, if there is one. The synthesizer is asked only then: its
    /// `isSpeaking` and `stopSpeaking` wait for the speech thread of the process to answer, which
    /// held the main thread up for 8 ms or so, twice with every card, in the stall probe.
    private func cutOff() {
        guard current != nil else { return }
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Speaks `text` once `delay` seconds have gone by, unless something stops or replaces it first.
    private func speak(_ text: String, after delay: Double) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            pending = nil
            speak(text)
        }
    }

    /// Returns once nothing is said or about to be, for work that can wait for a pause in the
    /// speech and not stall the main thread or take the processor while the voice is at it: the
    /// daily ring after a grade, the save of the deck, the widget. After `quietLimit` at most, and
    /// at once for a task that is cancelled.
    func whenQuiet() async {
        let deadline = ContinuousClock.now + Self.quietLimit
        while isBusy, !Task.isCancelled, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// The synthesizer says it is done with `utterance`, or was cut off.
    private func speechEnded(_ utterance: ObjectIdentifier) {
        guard let current, ObjectIdentifier(current) == utterance else { return }
        self.current = nil
        isSpeaking = false
    }

    private func simulateSpeech(for duration: Duration) {
        isSpeaking = true
        simulatedEnd?.cancel()
        simulatedEnd = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            isSpeaking = false
        }
    }

    /// A card came up, or the session ended (`nil`): with `autoSpeak`, speaks the question
    /// if it is Greek, after `settleDelay`. A card with another question speaks its answer
    /// once that shows, see `answerRevealed(of:)`.
    func cardAppeared(_ card: Card?) {
        if Self.isUnderTest { requests.append(.cardAppeared(card?.id)) }
        stop()
        guard autoSpeaks(), let card, canSpeak(card.question) else { return }
        speak(card.question, after: Self.settleDelay)
    }

    /// The answer of `card` shows: with `autoSpeak`, speaks it if it is Greek and the
    /// question wasn't, which `cardAppeared(_:)` has spoken then, after `revealDelay`.
    func answerRevealed(of card: Card) {
        // The head of the answer: a Greek example under a Russian gloss is not a Greek answer.
        let head = card.answer.prefix { !$0.isNewline }
        guard autoSpeaks(), !canSpeak(card.question), canSpeak(String(head)) else { return }
        speak(card.answer, after: Self.revealDelay)
    }

    /// Tells `GreekSpeech` when the synthesizer is done with an utterance. A class of its own,
    /// as a delegate is an `NSObject`; the callbacks come on any thread.
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        /// Set once, before the first utterance; called on the main actor.
        nonisolated(unsafe) var ended: (@MainActor (ObjectIdentifier) -> Void)?

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            end(ObjectIdentifier(utterance))
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            end(ObjectIdentifier(utterance))
        }

        private nonisolated func end(_ utterance: ObjectIdentifier) {
            Task { @MainActor in ended?(utterance) }
        }
    }
}

/// Where the speaker buttons of a card are, for the gestures of the card: a touch that starts on
/// one belongs to the button, so a press on the speaker neither shows the answer nor starts a
/// swipe nor opens the card's info. The card's view sets up the coordinate space named `space`
/// and passes this down through the environment (`speakerPlaces`); every speaker button that is
/// enabled reports its frame in it. A class and not view state, as nothing is drawn from it and
/// a change of it must not lay the card out again; it is only read and written on the main thread.
final class SpeakerPlaces: @unchecked Sendable {
    static let space = "speakerPlaces"

    private var byID: [UUID: CGRect] = [:]
    /// Whether the touch that is down, or was last, began on a speaker.
    var touchBeganOnSpeaker = false

    /// The speakers that can be touched now.
    var frames: [CGRect] { Array(byID.values) }

    func place(_ frame: CGRect?, of speaker: UUID) {
        byID[speaker] = frame
    }

    func contains(_ point: CGPoint) -> Bool {
        byID.values.contains { $0.contains(point) }
    }
}

extension EnvironmentValues {
    @Entry var speakerPlaces: SpeakerPlaces?
}

/// A small speaker button for `text`; nothing if it isn't Greek or the device has no
/// Greek voice. Placed beside the text it speaks.
///
/// Beside a word, pass the word's `font`: the symbol takes its size, so it scales with the
/// word, and has a first baseline of its own, so a row aligned by `.firstTextBaseline`
/// (`SpokenWord`) puts it on the first line of the word, whatever the size of the word and
/// however many lines it takes.
struct SpeakButton: View {
    var text: String
    var font: Font?

    @Environment(\.speakerPlaces) private var places
    @Environment(\.isEnabled) private var isEnabled
    @State private var id = UUID()
    @State private var frame = CGRect.zero

    var body: some View {
        if GreekSpeech.shared.canSpeak(text) {
            Button {
                GreekSpeech.shared.speak(text)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(font)
                    // Beside a word: as tall as its capitals (23 of 24 pt at the default size) and
                    // on its baseline, which the symbol's own baseline gives.
                    .imageScale(font == nil ? .large : .small)
                    .fontWeight(.regular)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
                    .onGeometryChange(
                        for: CGRect.self,
                        // Where there is no card to report to, there is no space to ask in.
                        of: { [places] in places == nil ? .zero : $0.frame(in: .named(SpeakerPlaces.space)) },
                        action: {
                            frame = $0
                            report()
                        })
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Pronounce"))
            // A disabled speaker (the answer's, while it is hidden) is no place to leave to it.
            .onChange(of: isEnabled) { report() }
            .onDisappear { places?.place(nil, of: id) }
            #if os(macOS)
            .help("Pronounce (S)")
            #endif
        }
    }

    private func report() {
        places?.place(isEnabled ? frame : nil, of: id)
    }
}
