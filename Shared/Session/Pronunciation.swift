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
/// Mac's S key and, if the learner wants it, by itself (`autoSpeak`). A card whose deck holds a
/// sound for its side plays that sound instead.
///
/// The voice is not played while it is computed. A word is rendered into a buffer first
/// (`AVSpeechSynthesizer.write`), as soon as its card comes up, and played from memory through an
/// `AVAudioEngine`. Spoken live, the synthesizer hands the output chunks of about 11 ms as it goes, and
/// on the iPhone 13 mini a chunk that comes late is a stutter. Rendering a word takes about 15 ms on a
/// Mac, so it is done long before the card has settled. Where rendering gives nothing, the word is
/// spoken live. `SpeechLog` notes how each word went.
///
/// One renderer, one engine and one audio session for the whole stream, set up when the stream
/// opens (`open()`) and let go of when it closes (`close()`), so a word never waits for the audio
/// hardware or for a change of category. The speech the stream asks for by itself starts only once
/// a card has settled: `cardAppeared(_:media:)` waits `settleDelay`, an answer that shows waits
/// `revealDelay`, and a card that leaves before that never speaks.
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
    /// fly-out of the one before (`CardFlight.duration`) have ended.
    static let settleDelay = 0.4
    /// The same for an answer that shows: its redraw (up to 80 ms in the stall probe) is over
    /// before the voice starts.
    static let revealDelay = 0.25
    /// The longest `whenQuiet()` waits: a speech that doesn't report its end holds nothing up for
    /// longer.
    static let quietLimit = Duration.seconds(4)
    /// The longest a word waits for its rendering before it is spoken live. The first word of a
    /// stream waits for the voice to load, 0.8 s on a Mac.
    static let renderLimit = 3.0
    /// A short silence before a word spoken live: the audio route is up by the time the first
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
    /// came up, an utterance and a sound of the deck. A second ask for the same card cuts the first
    /// speech off and starts it again, which sounds like a stutter.
    enum Request: Equatable {
        case cardAppeared(Card.ID?)
        case speak(String)
        case play(String)
    }

    private(set) var requests: [Request] = []

    var cardAppearedCount: Int { requests.count { if case .cardAppeared = $0 { true } else { false } } }
    var speakCount: Int { requests.count { if case .speak = $0 { true } else { false } } }

    /// Whether a card speaks by itself, asked when it does: the preference. A test has its own answer,
    /// as the preference is read by every test that runs.
    var autoSpeaks: () -> Bool = { GreekSpeech.autoSpeak }

    /// How long `whenQuiet()` waits at most; a test sets its own.
    var quietLimit = GreekSpeech.quietLimit

    /// For a test, which never speaks: how long a speech counts as lasting, so that what waits
    /// for the quiet does wait. `nil`, and then a test run is never busy.
    var simulatedSpeechDuration: Duration?

    /// Speaks live, where rendering gave nothing.
    private let synthesizer = AVSpeechSynthesizer()
    /// Renders the words ahead. A synthesizer of its own: stopping the live one empties its queue,
    /// and would take the words waiting to be rendered with it.
    private let renderer = AVSpeechSynthesizer()
    private let delegate = Delegate()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    /// The format the player is connected in, the voice's; `nil` until the engine first runs.
    private var playerFormat: AVAudioFormat?
    /// The words rendered or on their way, by word; started over at 64.
    private var renders: [String: Task<RenderedWord?, Never>] = [:]
    /// The word that waits for its rendering to be played.
    private var playing: Task<Void, Never>?
    /// Counts what is played and cut off, so the end of a buffer that was cut off doesn't end the next.
    private var playID = 0
    /// Whether a buffer plays now.
    private var bufferPlays = false
    /// The deck's sound that plays now.
    private var soundPlayer: AVAudioPlayer?
    /// The utterance that is said live now or waits to be said.
    private var current: AVSpeechUtterance?
    private var simulatedEnd: Task<Void, Never>?
    /// The speech a card asked for by itself and that waits for the card to settle.
    private var pending: Task<Void, Never>?
    private var isOpen = false
    /// Whether a word or a sound plays now or on its way to.
    private(set) var isSpeaking = false

    /// Whether the voice is, or is about to be, at work: a card waits for its settle time to speak,
    /// or a word or sound plays. A test run is never busy unless it simulates speech.
    var isBusy: Bool {
        (!Self.isUnderTest || simulatedSpeechDuration != nil) && (pending != nil || isSpeaking)
    }

    /// Not private, for the tests that need a voice of their own; the app uses `shared`.
    init() {
        synthesizer.delegate = delegate
        delegate.ended = { [weak self] id in self?.ended(id) }
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

    /// The head word of `text`: what comes before the first bracket or comma, so "χαλάω (χάλασα)"
    /// and "υπεύθυνος, -η, -ο" don't read out their forms, nor the example sentence under an answer.
    nonisolated static func headWord(of text: String) -> String {
        text.prefix { $0 != "(" && $0 != "," && !$0.isNewline }.trimmingCharacters(in: .whitespaces)
    }

    /// Prepares speaking for a stream that opens: the audio session, once, and the voice, which
    /// rendering a first word loads, and the engine. Does nothing without a Greek voice, and when
    /// already open.
    func open() {
        guard !Self.isUnderTest, voice != nil, !isOpen else { return }
        isOpen = true
        SpeechLog.add("open voice \(voice?.identifier ?? "-") quality \(voice?.quality.rawValue ?? 0)")
        #if os(iOS)
        activateSession(thenWarmUp: true)
        #else
        warmUp()
        #endif
    }

    /// The stream closes: stops what is said, lets go of the engine and hands the audio session
    /// back, so the other audio of the device goes on.
    func close() {
        stop()
        guard isOpen else { return }
        isOpen = false
        engine.stop()
        renders.removeAll()
        #if os(iOS)
        DispatchQueue.global(qos: .utility).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }

    /// Loads the voice by rendering a word, and starts the engine in the voice's format, so the
    /// first card waits for neither.
    private func warmUp() {
        let warm = render("ναι")
        Task { @MainActor in
            if let rendered = await warm.value, isOpen { _ = startEngine(for: rendered.buffer.format) }
        }
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

    /// Speaks the head word of `text` (`headWord(of:)`), from its rendering. What is still being
    /// spoken is cut off, and nothing else is stopped or started around it.
    func speak(_ text: String) {
        let word = Self.headWord(of: text)
        guard !word.isEmpty else { return }
        pending?.cancel()
        pending = nil
        if Self.isUnderTest {
            requests.append(.speak(word))
            if let duration = simulatedSpeechDuration { simulateSpeech(for: duration) }
            return
        }
        guard voice != nil else { return }
        cutOff()
        isSpeaking = true
        let asked = ContinuousClock.now
        let rendering = render(word)
        playing = Task { @MainActor in
            let rendered = await rendering.value
            guard !Task.isCancelled else { return }
            playing = nil
            let waited = Self.milliseconds(asked.duration(to: .now))
            if let rendered, play(rendered.buffer) {
                SpeechLog.add("play \(word) buffer waited \(waited) ms")
            } else {
                speakLive(word)
                SpeechLog.add("play \(word) live waited \(waited) ms")
            }
        }
    }

    /// Renders the head word of `text` ahead, so it plays at once when asked for.
    func prepare(_ text: String) {
        guard !Self.isUnderTest, isOpen, canSpeak(text) else { return }
        _ = render(Self.headWord(of: text))
    }

    /// Plays the deck's sound `name`, whose bytes `media` holds; does nothing without them. What is
    /// still being spoken is cut off.
    func play(sound name: String, of media: DeckMedia) {
        pending?.cancel()
        pending = nil
        if Self.isUnderTest {
            requests.append(.play(name))
            if let duration = simulatedSpeechDuration { simulateSpeech(for: duration) }
            return
        }
        guard let data = media.contents(of: name), let sound = try? AVAudioPlayer(data: data) else {
            SpeechLog.add("sound \(name) unreadable")
            return
        }
        cutOff()
        sound.delegate = delegate
        soundPlayer = sound
        isSpeaking = sound.play()
        SpeechLog.add("play sound \(name) \(isSpeaking ? "" : "failed")")
    }

    /// Cuts off what is being said and what waits to be said.
    func stop() {
        pending?.cancel()
        pending = nil
        simulatedEnd?.cancel()
        isSpeaking = false
        cutOff()
    }

    /// Stops what plays, if anything does. The live synthesizer is asked only when it speaks: its
    /// `isSpeaking` and `stopSpeaking` wait for the speech thread of the process to answer, which
    /// held the main thread up for 8 ms or so, twice with every card, in the stall probe.
    private func cutOff() {
        playing?.cancel()
        playing = nil
        playID += 1
        if bufferPlays {
            bufferPlays = false
            player.stop()
        }
        if let soundPlayer {
            self.soundPlayer = nil
            soundPlayer.stop()
        }
        guard current != nil else { return }
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Speaks `word` live, as it is computed.
    private func speakLive(_ word: String) {
        guard let voice else { return }
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        utterance.preUtteranceDelay = Self.preUtteranceDelay
        current = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// The rendering of `word`, started now unless it was before.
    private func render(_ word: String) -> Task<RenderedWord?, Never> {
        if let rendering = renders[word] { return rendering }
        if renders.count >= 64 { renders.removeAll() }
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        let rendering = Task { @MainActor [renderer] in
            let started = ContinuousClock.now
            let rendered = await Self.write(utterance, with: renderer)
            let took = Self.milliseconds(started.duration(to: .now))
            if let rendered {
                let length = Int(Double(rendered.buffer.frameLength) / rendered.buffer.format.sampleRate * 1000)
                SpeechLog.add("render \(word) \(took) ms, \(length) ms of sound")
            } else {
                SpeechLog.add("render \(word) gave nothing in \(took) ms")
            }
            return rendered
        }
        renders[word] = rendering
        return rendering
    }

    /// Renders `utterance` into one buffer, `nil` if the renderer gives no sound within `limit` seconds.
    static func write(_ utterance: AVSpeechUtterance, with renderer: AVSpeechSynthesizer, limit: Double = renderLimit) async -> RenderedWord? {
        await withCheckedContinuation { continuation in
            let chunks = Chunks(continuation)
            renderer.write(utterance) { chunks.add($0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + limit) { chunks.finish() }
        }
    }

    /// Plays `buffer` from its start; false where the engine can't run.
    private func play(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard startEngine(for: buffer.format) else { return false }
        playID += 1
        let id = playID
        bufferPlays = true
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.bufferEnded(id) }
        }
        player.play()
        return true
    }

    /// Runs the engine with the player connected in `format`; false where it won't start. The
    /// engine stops by itself when the audio route changes, and starts again with the next word.
    private func startEngine(for format: AVAudioFormat) -> Bool {
        if playerFormat != format {
            if playerFormat == nil { engine.attach(player) }
            engine.stop()
            engine.connect(player, to: engine.mainMixerNode, format: format)
            playerFormat = format
        }
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            SpeechLog.add("engine \(error.localizedDescription)")
            return false
        }
    }

    private func bufferEnded(_ id: Int) {
        guard id == playID else { return }
        bufferPlays = false
        isSpeaking = false
    }

    /// The live synthesizer is done with an utterance, or was cut off, or the deck's sound is over.
    private func ended(_ id: ObjectIdentifier) {
        if let current, ObjectIdentifier(current) == id {
            self.current = nil
            isSpeaking = false
        } else if let soundPlayer, ObjectIdentifier(soundPlayer) == id {
            self.soundPlayer = nil
            isSpeaking = false
        }
    }

    /// Speaks `text` once `delay` seconds have gone by, unless something stops or replaces it first.
    private func speak(_ text: String, after delay: Double) {
        later(delay) { $0.speak(text) }
    }

    private func play(sound name: String, of media: DeckMedia, after delay: Double) {
        later(delay) { $0.play(sound: name, of: media) }
    }

    private func later(_ delay: Double, _ action: @escaping @MainActor (GreekSpeech) -> Void) {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            pending = nil
            action(self)
        }
    }

    /// Returns once nothing is said or about to be, for work that can wait for a pause in the
    /// speech and not stall the main thread or take the processor while the voice is at it: the
    /// daily ring after a grade, the save of the deck, the widget. After `quietLimit` at most, and
    /// at once for a task that is cancelled.
    func whenQuiet() async {
        let deadline = ContinuousClock.now + quietLimit
        while isBusy, !Task.isCancelled, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
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

    /// A card came up, or the session ended (`nil`): with `autoSpeak`, plays the deck's sound of
    /// the question, or speaks the question if it is Greek, after `settleDelay`. A card with another
    /// question speaks its answer once that shows, see `answerRevealed(of:media:)`; its rendering
    /// starts now.
    func cardAppeared(_ card: Card?, media: DeckMedia = DeckMedia()) {
        if Self.isUnderTest { requests.append(.cardAppeared(card?.id)) }
        stop()
        guard autoSpeaks(), let card else { return }
        if let sound = card.questionAudio, Self.isUnderTest || media.contains(sound) {
            play(sound: sound, of: media, after: Self.settleDelay)
        } else if canSpeak(card.question) {
            prepare(card.question)
            speak(card.question, after: Self.settleDelay)
        } else {
            prepare(String(card.answer.prefix { !$0.isNewline }))
        }
    }

    /// The answer of `card` shows: with `autoSpeak`, plays the deck's sound of the answer, or speaks
    /// the answer if it is Greek and the question wasn't, which `cardAppeared(_:media:)` has spoken
    /// then, after `revealDelay`.
    func answerRevealed(of card: Card, media: DeckMedia = DeckMedia()) {
        guard autoSpeaks() else { return }
        if let sound = card.answerAudio, sound != card.questionAudio, Self.isUnderTest || media.contains(sound) {
            play(sound: sound, of: media, after: Self.revealDelay)
            return
        }
        // The head of the answer: a Greek example under a Russian gloss is not a Greek answer.
        let head = card.answer.prefix { !$0.isNewline }
        guard card.questionAudio == nil, !canSpeak(card.question), canSpeak(String(head)) else { return }
        speak(card.answer, after: Self.revealDelay)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }

    /// A word rendered into one buffer. Made once and then only read, from the main actor.
    struct RenderedWord: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
    }

    /// Joins the chunks the renderer hands over, on a thread of its own, into one buffer, and hands
    /// it on once: at the empty chunk that ends the word, or at `finish()` if that never comes.
    private final class Chunks: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<RenderedWord?, Never>?
        private var format: AVAudioFormat?
        /// The bytes of each buffer of the chunks' lists: one per channel, or one for all.
        private var bytes: [Data] = []
        private var frames: AVAudioFrameCount = 0

        init(_ continuation: CheckedContinuation<RenderedWord?, Never>) {
            self.continuation = continuation
        }

        /// Copies a chunk: the renderer may reuse its memory once the callback returns.
        func add(_ chunk: AVAudioBuffer) {
            guard let chunk = chunk as? AVAudioPCMBuffer, chunk.frameLength > 0 else { return finish() }
            let lists = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: chunk.audioBufferList))
            let size = Int(chunk.frameLength) * Int(chunk.format.streamDescription.pointee.mBytesPerFrame)
            lock.withLock {
                if format == nil {
                    format = chunk.format
                    bytes = Array(repeating: Data(), count: lists.count)
                }
                guard chunk.format == format, lists.count == bytes.count else { return }
                for (index, list) in lists.enumerated() {
                    guard let data = list.mData else { continue }
                    bytes[index].append(data.assumingMemoryBound(to: UInt8.self), count: min(size, Int(list.mDataByteSize)))
                }
                frames += chunk.frameLength
            }
        }

        func finish() {
            let (continuation, format, bytes, frames) = lock.withLock {
                defer { self.continuation = nil }
                return (self.continuation, self.format, self.bytes, self.frames)
            }
            guard let continuation else { return }
            guard let format, frames > 0, let joined = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                return continuation.resume(returning: nil)
            }
            joined.frameLength = frames
            for (list, data) in zip(UnsafeMutableAudioBufferListPointer(joined.mutableAudioBufferList), bytes) {
                guard let target = list.mData else { continue }
                data.withUnsafeBytes { target.copyMemory(from: $0.baseAddress!, byteCount: min(data.count, Int(list.mDataByteSize))) }
            }
            continuation.resume(returning: Self.standard(joined).map(RenderedWord.init))
        }

        /// `buffer` in the format a player node plays, 32-bit floats a channel each: compact voices
        /// render 16-bit integers, premium ones floats.
        private static func standard(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
            guard !buffer.format.isStandard else { return buffer }
            guard let format = AVAudioFormat(standardFormatWithSampleRate: buffer.format.sampleRate, channels: buffer.format.channelCount),
                let converter = AVAudioConverter(from: buffer.format, to: format),
                let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength),
                (try? converter.convert(to: converted, from: buffer)) != nil
            else { return nil }
            return converted
        }
    }

    /// Tells `GreekSpeech` when the live synthesizer is done with an utterance and when the deck's
    /// sound is over. A class of its own, as a delegate is an `NSObject`; the callbacks come on any
    /// thread.
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate, @unchecked Sendable {
        /// Set once, before the first utterance; called on the main actor.
        nonisolated(unsafe) var ended: (@MainActor (ObjectIdentifier) -> Void)?

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            end(ObjectIdentifier(utterance))
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            end(ObjectIdentifier(utterance))
        }

        nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            end(ObjectIdentifier(player))
        }

        private nonisolated func end(_ id: ObjectIdentifier) {
            Task { @MainActor in ended?(id) }
        }
    }
}

/// A line for each word the speech renders and plays, in `Library/Caches/speech.log` of the app: how
/// long rendering took against the length of the word, and whether it played from the buffer or
/// live, after how long a wait. The measure of the stutter on the iPhone, read off it with
/// `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.euf.mnemit.ios
/// --source Library/Caches/speech.log`. It starts over past 64 KB; a test run writes nothing.
enum SpeechLog {
    private static let queue = DispatchQueue(label: "SpeechLog", qos: .utility)
    private static let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("speech.log")

    nonisolated static func add(_ line: String) {
        guard !GreekSpeech.isUnderTest else { return }
        let data = Data("\(Date().formatted(.iso8601)) \(line)\n".utf8)
        queue.async {
            guard let file = try? FileHandle(forWritingTo: url) else {
                try? data.write(to: url)
                return
            }
            defer { try? file.close() }
            if let end = try? file.seekToEnd(), end > 65_536 {
                try? file.truncate(atOffset: 0)
            }
            try? file.write(contentsOf: data)
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
/// Greek voice. Placed beside the text it speaks. A side that has a `sound` the deck's `media`
/// holds gets the button whatever its text, and a tap plays the sound instead of speaking.
///
/// Beside a word, pass the word's `font`: the symbol takes its size, so it scales with the
/// word, and has a first baseline of its own, so a row aligned by `.firstTextBaseline`
/// (`SpokenWord`) puts it on the first line of the word, whatever the size of the word and
/// however many lines it takes.
struct SpeakButton: View {
    var text: String
    var font: Font?
    var sound: String?
    var media: DeckMedia?

    @Environment(\.speakerPlaces) private var places
    @Environment(\.isEnabled) private var isEnabled
    @State private var id = UUID()
    @State private var frame = CGRect.zero

    /// The deck's sound of the side, if it has one.
    private var playable: String? {
        guard let sound, media?.contains(sound) == true else { return nil }
        return sound
    }

    var body: some View {
        if playable != nil || GreekSpeech.shared.canSpeak(text) {
            Button {
                if let playable, let media {
                    GreekSpeech.shared.play(sound: playable, of: media)
                } else {
                    GreekSpeech.shared.speak(text)
                }
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
