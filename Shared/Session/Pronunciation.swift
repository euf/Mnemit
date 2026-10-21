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
@MainActor
final class GreekSpeech {
    static let shared = GreekSpeech()

    /// The preference "Speak Greek automatically": a card speaks its Greek side by itself.
    nonisolated static let autoSpeakKey = "speakGreekAutomatically"

    /// On until the learner turns it off.
    nonisolated static var autoSpeak: Bool {
        UserDefaults.standard.object(forKey: autoSpeakKey) as? Bool ?? true
    }

    /// The best voice for Greek the device has; `nil` without one, and the speaker
    /// buttons stay hidden. Looked up once: a voice installed meanwhile shows after a restart.
    let voice = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == "el-GR" }
        .max { $0.quality.rawValue < $1.quality.rawValue }

    private let synthesizer = AVSpeechSynthesizer()

    /// Whether `text` can be spoken: it is Greek, and a voice is there.
    func canSpeak(_ text: String) -> Bool {
        voice != nil && text.containsGreek
    }

    /// Speaks the head word of `text`: what comes before the first bracket or comma, so
    /// "χαλάω (χάλασα)" and "υπεύθυνος, -η, -ο" don't read out their forms. Cuts off
    /// what is still being spoken.
    func speak(_ text: String) {
        let word = text.prefix { $0 != "(" && $0 != "," }.trimmingCharacters(in: .whitespaces)
        guard let voice, !word.isEmpty else { return }
        #if os(iOS)
        // Spoken even with the ringer switch on silent: the learner asked for it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        #endif
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    /// Cuts off what is being said.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// A card came up, or the session ended (`nil`): stops what the last card was saying
    /// and, with `autoSpeak`, speaks the question if it is Greek. A card with another
    /// question speaks its answer once that shows, see `answerRevealed(of:)`.
    func cardAppeared(_ card: Card?) {
        stop()
        guard Self.autoSpeak, let card, canSpeak(card.question) else { return }
        speak(card.question)
    }

    /// The answer of `card` shows: with `autoSpeak`, speaks it if it is Greek and the
    /// question wasn't, which `cardAppeared(_:)` has spoken then.
    func answerRevealed(of card: Card) {
        guard Self.autoSpeak, !canSpeak(card.question), canSpeak(card.answer) else { return }
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
