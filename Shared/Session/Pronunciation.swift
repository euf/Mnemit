import AVFoundation
import SwiftUI

extension String {
    /// Whether the text has Greek letters, of the modern alphabet or the polytonic one.
    var containsGreek: Bool {
        unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x1F00...0x1FFF).contains($0.value) }
    }
}

/// Speaks Greek text with a voice installed on the device, for the speaker button and the
/// Mac's S key.
@MainActor
final class GreekSpeech {
    static let shared = GreekSpeech()

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
