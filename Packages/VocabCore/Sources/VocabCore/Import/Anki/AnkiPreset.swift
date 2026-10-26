import Foundation

/// A deck preset (an options group) of Anki, as far as an import reads it: the FSRS
/// settings its cards were scheduled with.
public struct AnkiPreset: Sendable, Equatable {
    public var name: String
    /// The FSRS parameters the preset stores: 21 values (FSRS-6), 19 (FSRS-5), 17
    /// (FSRS-4.5), or none if it was never optimized; another count is kept as it is.
    public var parameters: [Float]
    /// The desired retention; `nil` if the preset has none (proto3 leaves out 0).
    public var desiredRetention: Float?
    /// What the preset does about leeches; `nil` if it stores nothing about them.
    public var leech: Leech?

    /// Anki's leech threshold and action, as Mnemit's `LearningOptions` take them: its "suspend" is
    /// `LeechAction.suspend`, its "tag only" is `LeechAction.keep`.
    public struct Leech: Sendable, Equatable {
        public var threshold: Int
        public var action: LeechAction

        public init(threshold: Int, action: LeechAction) {
            self.threshold = threshold
            self.action = action
        }

        /// From Anki's `leech_action` (0 suspend, 1 tag only) and `leech_threshold`.
        init(ankiThreshold: Int, ankiAction: Int) {
            self.init(threshold: ankiThreshold, action: ankiAction == 1 ? .keep : .suspend)
        }
    }

    public init(name: String, parameters: [Float] = [], desiredRetention: Float? = nil, leech: Leech? = nil) {
        self.name = name
        self.parameters = parameters
        self.desiredRetention = desiredRetention
        self.leech = leech
    }

    /// The preset of a configuration with its three parameter lists. Anki keeps one list
    /// per FSRS version and takes the newest that isn't empty (`DeckConfig::fsrs_params`
    /// in rslib's `deckconfig/mod.rs`).
    init(name: String, fsrs4: [Float], fsrs5: [Float], fsrs6: [Float], desiredRetention: Float, leech: Leech? = nil) {
        let parameters = [fsrs6, fsrs5, fsrs4].first { !$0.isEmpty } ?? []
        self.init(name: name, parameters: parameters, desiredRetention: desiredRetention.isFinite && desiredRetention > 0 ? desiredRetention : nil, leech: leech)
    }

    /// Anki's own default retention. A preset that has this one and no parameters says
    /// nothing about FSRS: it is the stock preset of a collection that never used it.
    static let defaultRetention: Float = 0.9

    /// The parameters as the 21 values of FSRS-6, `nil` if there are none or not a set
    /// Anki reads: 17 and 19 values are filled up the way Anki does when it reads an
    /// older set, `check_and_fill_parameters_fsrs6` in fsrs-rs 6.6.2 (`model_v6.rs`, called
    /// by `FSRS::new`, the version rslib depends on), and every value is then kept in its
    /// range, as `clip_parameters` does there. One range differs: fsrs-rs leaves w19 at 0
    /// for such a set, Mnemit's floor is 0.01 (a deck with a smaller w19 is refused), a
    /// factor of S^-0.01 on the stability after a same-day review.
    public var fsrsParameters: FSRSParameters? {
        guard parameters.allSatisfy(\.isFinite) else { return nil }
        var w = parameters
        switch w.count {
        case 17:
            // FSRS-4.5: w4 and w5 move to FSRS-6's difficulty, w6 gains 0.5, and the new
            // w17 to w19 are 0 with FSRS-5's fixed decay of 0.5 as w20.
            w[4] = w[4].addingProduct(w[5], 2)
            w[5] = log(Float(1).addingProduct(w[5], 3)) / 3
            w[6] += 0.5
            w += [0, 0, 0, 0.5]
        case 19:
            // FSRS-5: no short-term weight and the same fixed decay.
            w += [0, 0.5]
        case FSRSParameters.count:
            break
        default:
            return nil
        }
        // The shortest decimal of each value, so 0.9 stays 0.9 and not 0.8999999761581421.
        let values = w.enumerated().map { Double("\($0.element)")!.clamped(to: FSRSParameters.ranges[$0.offset]) }
        return FSRSParameters(values)
    }

    /// Whether the preset says anything about FSRS that Mnemit can take: readable
    /// parameters, or a desired retention other than Anki's default.
    var hasFSRSSettings: Bool {
        fsrsParameters != nil || desiredRetention.map { $0 != Self.defaultRetention } == true
    }

    /// `options` with the preset's parameters and desired retention, the retention kept in
    /// the range Mnemit offers (`LearningOptions.sanitize()`); `nil` if the preset has no
    /// FSRS settings (`hasFSRSSettings`). A set of parameters that isn't readable is left
    /// out, and the retention still goes in.
    public func learningOptions(applyingTo options: LearningOptions) -> LearningOptions? {
        guard hasFSRSSettings else { return nil }
        var result = options
        if let fsrsParameters { result.parameters = fsrsParameters }
        if let desiredRetention { result.targetRecall = Double("\(desiredRetention)")! }
        result.sanitize()
        return result
    }
}

extension AnkiPreset {
    /// `options` with the preset's leech threshold and action, the threshold kept in the range Mnemit
    /// offers; `nil` if the preset stores none.
    public func learningOptions(applyingLeechTo options: LearningOptions) -> LearningOptions? {
        guard let leech else { return nil }
        var result = options
        result.leechThreshold = leech.threshold
        result.leechAction = leech.action
        result.sanitize()
        return result
    }
}

extension AnkiImport {
    /// The preset most of the cards of `notes` use; the first of `presets` if two share the
    /// most. `nil` if no card has one.
    public var dominantPreset: AnkiPreset? {
        let counts = Dictionary(grouping: notes.compactMap(\.preset), by: { $0 }).mapValues(\.count)
        guard let best = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) else { return nil }
        return presets[best.key]
    }

    /// `options` as the preset most cards use sets them (`AnkiPreset.learningOptions(applyingTo:)`),
    /// for a deck that is new; `nil` if that preset has no FSRS settings or no card has one.
    public func learningOptions(applyingTo options: LearningOptions) -> LearningOptions? {
        dominantPreset?.learningOptions(applyingTo: options)
    }

    /// `learningOptions(applyingTo:)` and the leech settings of the same preset, for a deck that is
    /// new; `nil` if the preset has neither, or no card has one.
    public func deckOptions(applyingTo options: LearningOptions) -> LearningOptions? {
        let fsrs = learningOptions(applyingTo: options)
        return dominantPreset?.learningOptions(applyingLeechTo: fsrs ?? options) ?? fsrs
    }
}
