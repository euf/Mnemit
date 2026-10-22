import Foundation
import Testing

@testable import VocTrain
@testable import VocabCore

/// What waits for the voice: work that can wait asks `whenQuiet()`, and the voice is busy from
/// the moment a card is about to speak until it is through. A voice of the test's own, so the
/// speech of the other tests, which share `GreekSpeech.shared`, is not held up. The tests share the
/// main actor with others that keep it busy for seconds, so they give the waits a long limit and
/// check what happened and the least time it took, not the most.
@MainActor
struct GreekSpeechQuietTests {
    let created = Date(timeIntervalSince1970: 1_791_216_000)

    private func card(_ question: String, answer: String) -> Card {
        Card(text: CardText(question: question, answer: answer)!, created: created)
    }

    /// A voice that waits for a speech as long as it takes.
    private func patientVoice() -> GreekSpeech {
        let speech = GreekSpeech()
        speech.quietLimit = .seconds(600)
        return speech
    }

    /// The time `work` takes, in seconds.
    private func seconds(_ work: () async -> Void) async -> Double {
        let start = ContinuousClock.now
        await work()
        return (ContinuousClock.now - start) / .seconds(1)
    }

    @Test func nothingWaitsWhileNothingIsSpoken() async {
        let speech = patientVoice()
        #expect(!speech.isBusy)
        #expect(await seconds { await speech.whenQuiet() } < 60)
    }

    @Test func whatCanWaitWaitsForTheSpeechToEnd() async {
        let speech = patientVoice()
        speech.simulatedSpeechDuration = .milliseconds(400)
        speech.speak("δρόμος")
        #expect(speech.isBusy)
        #expect(await seconds { await speech.whenQuiet() } >= 0.35)
        #expect(!speech.isBusy)
    }

    @Test func stoppingEndsTheBusyTimeAtOnce() async {
        let speech = patientVoice()
        speech.simulatedSpeechDuration = .seconds(600)
        speech.speak("δρόμος")
        #expect(speech.isBusy)
        speech.stop()
        #expect(!speech.isBusy)
        #expect(await seconds { await speech.whenQuiet() } < 60)
    }

    @Test func aWaitEndsByItsLimitWhenTheSpeechDoesNot() async {
        let speech = GreekSpeech()
        speech.quietLimit = .milliseconds(300)
        speech.simulatedSpeechDuration = .seconds(600)
        speech.speak("δρόμος")
        #expect(await seconds { await speech.whenQuiet() } >= 0.25)
        #expect(speech.isBusy)
        speech.stop()
    }

    @Test func aCancelledTaskDoesNotWait() async {
        let speech = patientVoice()
        speech.simulatedSpeechDuration = .seconds(600)
        speech.speak("δρόμος")
        let task = Task { await seconds { await speech.whenQuiet() } }
        task.cancel()
        #expect(await task.value < 60)
        speech.stop()
    }

    /// A card is busy from the moment it comes up: it speaks after `settleDelay`, and the work waits
    /// for that too.
    @Test func aCardThatWillSpeakIsBusyFromTheStart() async {
        let speech = patientVoice()
        speech.autoSpeaks = { true }
        speech.simulatedSpeechDuration = .milliseconds(200)
        speech.cardAppeared(card("το σπίτι", answer: "дом"))
        #expect(speech.isBusy)
        #expect(speech.speakCount == 0)
        #expect(await seconds { await speech.whenQuiet() } >= GreekSpeech.settleDelay)
        #expect(speech.speakCount == 1)
    }

    /// A card with a Russian question speaks its Greek answer, a moment after it shows: the redraw
    /// of the answer comes first.
    @Test func anAnswerIsSpokenAfterItsRedraw() async throws {
        let speech = patientVoice()
        speech.autoSpeaks = { true }
        let start = ContinuousClock.now
        speech.answerRevealed(of: card("дом", answer: "το σπίτι"))
        #expect(speech.speakCount == 0)
        try await waitUntil("the answer is asked for") { speech.speakCount > 0 }
        #expect((ContinuousClock.now - start) / .seconds(1) >= GreekSpeech.revealDelay)
        #expect(speech.requests == [.speak("το σπίτι")])
    }
}
