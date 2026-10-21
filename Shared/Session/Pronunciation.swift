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
/// starts only once a card has settled: `cardAppeared(_:)` waits `settleDelay`, and a card
/// that leaves before that never speaks.
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

    private let synthesizer = AVSpeechSynthesizer()
    /// The speech a card asked for by itself and that waits for the card to settle.
    private var pending: Task<Void, Never>?
    private var isOpen = false

    private init() {
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

    /// Whether `text` can be spoken: it is Greek, and a voice is there.
    func canSpeak(_ text: String) -> Bool {
        voice != nil && text.containsGreek
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
        guard !Self.isUnderTest, let voice, !word.isEmpty else { return }
        pending?.cancel()
        pending = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        utterance.preUtteranceDelay = Self.preUtteranceDelay
        synthesizer.speak(utterance)
    }

    /// Cuts off what is being said and what waits to be said.
    func stop() {
        pending?.cancel()
        pending = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// A card came up, or the session ended (`nil`): with `autoSpeak`, speaks the question
    /// if it is Greek, after `settleDelay`. A card with another question speaks its answer
    /// once that shows, see `answerRevealed(of:)`.
    func cardAppeared(_ card: Card?) {
        stop()
        guard Self.autoSpeak, let card, canSpeak(card.question) else { return }
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.settleDelay))
            guard !Task.isCancelled else { return }
            speak(card.question)
        }
    }

    /// The answer of `card` shows: with `autoSpeak`, speaks it if it is Greek and the
    /// question wasn't, which `cardAppeared(_:)` has spoken then.
    func answerRevealed(of card: Card) {
        // The head of the answer: a Greek example under a Russian gloss is not a Greek answer.
        let head = card.answer.prefix { !$0.isNewline }
        guard Self.autoSpeak, !canSpeak(card.question), canSpeak(String(head)) else { return }
        speak(card.answer)
    }
}

/// A small speaker button for `text`; nothing if it isn't Greek or the device has no
/// Greek voice. Placed beside the text it speaks.
struct SpeakButton: View {
    var text: String

    var body: some View {
        if GreekSpeech.shared.canSpeak(text) {
            Button {
                GreekSpeech.shared.speak(text)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .imageScale(.large)
                    .frame(minWidth: 28, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Pronounce"))
            #if os(macOS)
            .help("Pronounce (S)")
            #endif
        }
    }
}
