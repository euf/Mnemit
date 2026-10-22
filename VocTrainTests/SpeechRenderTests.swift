import AVFoundation
import Testing

@testable import VocTrain

/// The words the speech plays are rendered ahead into one buffer (`GreekSpeech.write`): the chunks
/// the renderer hands over are joined whole, with no gap where one chunk meets the next. Skipped
/// where the simulator has no Greek voice.
@MainActor @Suite(.enabled(if: AVSpeechSynthesisVoice.speechVoices().contains { $0.language == "el-GR" }))
struct SpeechRenderTests {
    @Test func aWordIsRenderedWholeIntoOneBuffer() async throws {
        let voice = try #require(AVSpeechSynthesisVoice.speechVoices().first { $0.language == "el-GR" })
        let renderer = AVSpeechSynthesizer()
        for word in ["καλημέρα", "ευχαριστώ", "ο σκύλος", "η θάλασσα"] {
            let utterance = AVSpeechUtterance(string: word)
            utterance.voice = voice
            let rendered = try #require(await GreekSpeech.write(utterance, with: renderer), "\(word)")
            let buffer = rendered.buffer
            let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
            #expect((0.3...3).contains(seconds), "\(word): \(seconds) s")
            // Loud from the first syllable to the last, with no stretch of silence longer than a
            // stop consonant (up to about 60 ms): a lost or misplaced chunk would leave one.
            let samples = try #require(Self.samples(of: buffer))
            let loud = samples.indices.filter { abs(samples[$0]) > 0.003 }
            let first = try #require(loud.first)
            let last = try #require(loud.last)
            let longestQuiet = zip(loud, loud.dropFirst()).map { $1 - $0 }.max() ?? 0
            #expect(Double(longestQuiet) / buffer.format.sampleRate < 0.12, "\(word)")
            #expect(Double(last - first) / buffer.format.sampleRate > 0.2, "\(word)")
        }
    }

    private static func samples(of buffer: AVAudioPCMBuffer) -> [Float]? {
        let count = Int(buffer.frameLength)
        if let floats = buffer.floatChannelData { return Array(UnsafeBufferPointer(start: floats[0], count: count)) }
        if let ints = buffer.int16ChannelData { return UnsafeBufferPointer(start: ints[0], count: count).map { Float($0) / 32768 } }
        return nil
    }
}
