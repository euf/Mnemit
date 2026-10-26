import Foundation
import Testing

@testable import VocabCore

/// The deck presets of an Anki package: what is read, how older parameter sets are filled up, and
/// what a new deck takes. The rules are those of fsrs-rs 6.6.2 (`check_and_fill_parameters_fsrs6`,
/// `clip_parameters`) and rslib (`DeckConfig::fsrs_params`), see `AnkiPreset.fsrsParameters`.
struct AnkiPresetTests {
    typealias Fixtures = AnkiFixtures

    /// The defaults of FSRS-6, and their first 19 and 17 values as sets of the older versions.
    static let six = FSRSParameters.default.weights.map { Float($0) }
    static let five = Array(six.prefix(19))
    static let four = Array(six.prefix(17))

    // MARK: Parameter sets

    @Test func aSetOf21ValuesIsTakenAsItIs() {
        #expect(AnkiPreset(name: "a", parameters: Self.six).fsrsParameters == .default)
        var custom = Self.six
        custom[0] = 0.3178
        custom[20] = 0.173
        #expect(AnkiPreset(name: "a", parameters: custom).fsrsParameters?.weights[0] == 0.3178)
        #expect(AnkiPreset(name: "a", parameters: custom).fsrsParameters?.weights[20] == 0.173)
    }

    @Test func aSetOf19ValuesGainsTheShortTermWeightAndTheFixedDecay() throws {
        let weights = try #require(AnkiPreset(name: "a", parameters: Self.five).fsrsParameters).weights
        #expect(weights.count == 21)
        #expect(Array(weights.prefix(19)) == Array(FSRSParameters.default.weights.prefix(19)))
        #expect(weights[19] == 0.01)  // 0, which the range of w19 lifts to its floor
        #expect(weights[20] == 0.5)
    }

    @Test func aSetOf17ValuesIsConvertedFromFSRS45() throws {
        let input = Self.four.map(Double.init)
        let weights = try #require(AnkiPreset(name: "a", parameters: Self.four).fsrsParameters).weights
        #expect(weights.count == 21)
        // w4 and w5 are rebuilt, w6 gains 0.5, the rest stays; then w17 and w18 are 0, w19 its floor and w20 0.5.
        #expect(abs(weights[4] - (input[4] + 2 * input[5])) < 1e-5)
        #expect(abs(weights[5] - log(1 + 3 * input[5]) / 3) < 1e-5)
        #expect(abs(weights[6] - (input[6] + 0.5)) < 1e-5)
        for index in [0, 1, 2, 3, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16] {
            #expect(weights[index] == FSRSParameters.default.weights[index])
        }
        #expect(weights[17...20] == [0, 0, 0.01, 0.5])
    }

    @Test func otherCountsAndBrokenValuesAreIgnored() {
        for count in [0, 1, 16, 18, 20, 22, 34] {
            #expect(AnkiPreset(name: "a", parameters: Array(repeating: 1, count: count)).fsrsParameters == nil)
        }
        var broken = Self.six
        broken[3] = .nan
        #expect(AnkiPreset(name: "a", parameters: broken).fsrsParameters == nil)
        broken[3] = .infinity
        #expect(AnkiPreset(name: "a", parameters: broken).fsrsParameters == nil)
    }

    @Test func valuesOutsideTheirRangeAreKeptInIt() throws {
        var wild = Self.six
        wild[0] = 500
        wild[4] = 40
        wild[20] = 0.01
        let weights = try #require(AnkiPreset(name: "a", parameters: wild).fsrsParameters)
        #expect(weights.indexOutOfRange == nil)
        #expect(weights[0] == 100 && weights[4] == 10 && weights[20] == 0.1)
    }

    // MARK: What a new deck takes

    @Test func aPresetSetsParametersAndRetentionAndLeavesTheRestAlone() throws {
        var deck = LearningOptions()
        deck.steps = 3
        deck.fuzzing = false
        var custom = Self.six
        custom[1] = 1.5
        let applied = try #require(AnkiPreset(name: "a", parameters: custom, desiredRetention: 0.85).learningOptions(applyingTo: deck))
        #expect(applied.parameters.weights[1] == 1.5)
        #expect(applied.targetRecall == 0.85)
        #expect(applied.steps == 3 && !applied.fuzzing)
    }

    @Test func theRetentionIsKeptInTheRangeMnemitOffers() throws {
        func target(_ retention: Float) throws -> Double {
            try #require(AnkiPreset(name: "a", parameters: Self.six, desiredRetention: retention).learningOptions(applyingTo: LearningOptions())).targetRecall
        }
        #expect(try target(0.99) == LearningOptions.targetRecallRange.upperBound)
        #expect(try target(0.5) == LearningOptions.targetRecallRange.lowerBound)
        #expect(try target(0.9) == 0.9)
        #expect(try target(0.95) == 0.95)
    }

    @Test func parametersMnemitCantReadLeaveTheDefaultsButTheRetentionStays() throws {
        let applied = try #require(AnkiPreset(name: "a", parameters: Array(repeating: 1, count: 34), desiredRetention: 0.8).learningOptions(applyingTo: LearningOptions()))
        #expect(applied.parameters == .default)
        #expect(applied.targetRecall == 0.8)
    }

    @Test func aPresetWithoutFSRSSettingsChangesNothing() {
        // Anki's stock preset: no parameters, the default retention, or none at all.
        #expect(AnkiPreset(name: "Default", desiredRetention: 0.9).learningOptions(applyingTo: LearningOptions()) == nil)
        #expect(AnkiPreset(name: "Default").learningOptions(applyingTo: LearningOptions()) == nil)
        #expect(AnkiPreset(name: "Default", parameters: [1, 2, 3], desiredRetention: 0.9).learningOptions(applyingTo: LearningOptions()) == nil)
        // A retention of its own is a setting, parameters or not.
        #expect(AnkiPreset(name: "Default", desiredRetention: 0.85).learningOptions(applyingTo: LearningOptions())?.targetRecall == 0.85)
    }

    @Test func theNewestParameterListWins() {
        let preset = AnkiPreset(name: "a", fsrs4: Self.four, fsrs5: Self.five, fsrs6: Self.six, desiredRetention: 0.9)
        #expect(preset.parameters == Self.six)
        #expect(AnkiPreset(name: "a", fsrs4: Self.four, fsrs5: Self.five, fsrs6: [], desiredRetention: 0.9).parameters == Self.five)
        #expect(AnkiPreset(name: "a", fsrs4: Self.four, fsrs5: [], fsrs6: [], desiredRetention: 0.9).parameters == Self.four)
        #expect(AnkiPreset(name: "a", fsrs4: [], fsrs5: [], fsrs6: [], desiredRetention: 0).desiredRetention == nil)
        #expect(AnkiPreset(name: "a", fsrs4: [], fsrs5: [], fsrs6: [], desiredRetention: .nan).desiredRetention == nil)
    }

    @Test func theDominantPresetIsTheOneMostCardsUse() {
        let presets = [AnkiPreset(name: "a"), AnkiPreset(name: "b"), AnkiPreset(name: "c")]
        func dominant(_ used: [Int?]) -> String? {
            AnkiImport(notes: used.map { AnkiImport.Note(front: "x", back: "y", preset: $0) }, presets: presets).dominantPreset?.name
        }
        #expect(dominant([1, 2, 1, 0, nil, nil, nil]) == "b")
        #expect(dominant([2, 0, 2, 0]) == "a")  // a tie goes to the first
        #expect(dominant([nil, nil]) == nil)
        #expect(dominant([]) == nil)
    }

    // MARK: Reading

    static let customSix = Self.six.enumerated().map { $0.offset == 0 ? Float(0.3178) : $0.element }

    private static let presets = [
        Fixtures.RawPreset(id: 1, name: "Default"),
        Fixtures.RawPreset(id: 5, name: "Mine", fsrs4: four, fsrs5: five, fsrs6: customSix, desiredRetention: 0.85),
        Fixtures.RawPreset(id: 6, name: "Old", fsrs4: four, desiredRetention: 0.8),
        Fixtures.RawPreset(id: 7, name: "Five", fsrs5: five, desiredRetention: nil),
        Fixtures.RawPreset(id: 8, name: "Unused", fsrs6: six, desiredRetention: 0.95),
    ]

    private static let decks = [1: "Default", 10: "Greek::Lesson 1", 11: "Greek::Lesson 2", 12: "Greek::Lesson 3", 13: "Greek::Lesson 4", 99: "Filtered Deck 1"]

    /// Lesson 1 uses "Mine", 2 uses "Old", 3 names a preset the package lacks, 4 uses "Five"; the filtered deck
    /// has a preset of its own, which its card doesn't take: it keeps the one of the deck it came from.
    private static let deckPresets = [1: 1, 10: 5, 11: 6, 12: 42, 13: 7, 99: 8]

    private static let notes = (0..<6).map { Fixtures.RawNote(id: 100 + $0, model: 1, fields: ["q\($0)", "a\($0)"]) }
    private static let cards = [
        Fixtures.RawCard(id: 1000, note: 100, deck: 10),
        Fixtures.RawCard(id: 1001, note: 101, deck: 11),
        Fixtures.RawCard(id: 1002, note: 102, deck: 12),
        Fixtures.RawCard(id: 1003, note: 103, deck: 13),
        Fixtures.RawCard(id: 1004, note: 104, deck: 99, filteredFrom: 11),
        Fixtures.RawCard(id: 1005, note: 105, deck: 10),
    ]

    private static func read(current: Bool, presets: [Fixtures.RawPreset]? = Self.presets) throws -> AnkiImport {
        let collection =
            current
            ? Fixtures.currentCollection(decks: decks, presets: presets, deckPresets: deckPresets, notes: notes, cards: cards)
            : Fixtures.legacyCollection(decks: decks, presets: presets, deckPresets: deckPresets, notes: notes, cards: cards)
        return try AnkiImport.read(Fixtures.zip([("collection.anki2", collection)]))
    }

    @Test(arguments: [false, true])
    func readsThePresetsTheCardsUse(current: Bool) throws {
        let result = try Self.read(current: current)
        // Those the cards use, by number in Anki; "Unused" (the filtered deck's) is not among them.
        #expect(result.presets.map(\.name) == ["Mine", "Old", "Five"])
        #expect(result.notes.map(\.preset) == [0, 1, nil, 2, 1, 0])
        #expect(result.presets[0] == AnkiPreset(name: "Mine", parameters: Self.customSix, desiredRetention: 0.85))
        #expect(result.presets[1] == AnkiPreset(name: "Old", parameters: Self.four, desiredRetention: 0.8))
        #expect(result.presets[2] == AnkiPreset(name: "Five", parameters: Self.five, desiredRetention: nil))
        #expect(result.dominantPreset?.name == "Mine")
    }

    @Test func schema18ReadsListsThatAreNotPacked() throws {
        var presets = Self.presets
        presets[1].isPacked = false
        presets[2].isPacked = false
        let result = try Self.read(current: true, presets: presets)
        #expect(result.presets[0].parameters == Self.customSix)
        #expect(result.presets[1].parameters == Self.four)
    }

    @Test(arguments: [false, true])
    func aCollectionWithoutPresetsStillImports(current: Bool) throws {
        let result = try Self.read(current: current, presets: nil)
        #expect(result.notes.count == 6)
        #expect(result.presets.isEmpty && result.notes.allSatisfy { $0.preset == nil })
        #expect(result.dominantPreset == nil && result.learningOptions(applyingTo: LearningOptions()) == nil)
    }

    @Test(arguments: [false, true])
    func aNewDeckTakesTheSettingsOfTheDominantPreset(current: Bool) throws {
        let options = try #require(Self.read(current: current).learningOptions(applyingTo: LearningOptions()))
        #expect(options.targetRecall == 0.85)
        #expect(options.parameters.weights[0] == 0.3178)
        #expect(options.parameters.weights[1...] == FSRSParameters.default.weights[1...])
    }

    // MARK: Leeches

    @Test(arguments: [false, true])
    func readsTheLeechSettingsOfAPreset(current: Bool) throws {
        let presets = [
            Fixtures.RawPreset(id: 5, name: "Tag", desiredRetention: nil, leech: (5, 1)),
            Fixtures.RawPreset(id: 6, name: "Suspend", desiredRetention: nil, leech: (12, 0)),
            Fixtures.RawPreset(id: 7, name: "None", desiredRetention: nil),
        ]
        let result = try Self.read(current: current, presets: presets)
        #expect(result.presets.map(\.leech) == [AnkiPreset.Leech(threshold: 5, action: .keep), .init(threshold: 12, action: .suspend), nil])
    }

    @Test func aNewDeckTakesTheLeechSettingsWithOrWithoutFSRSSettings() throws {
        let stock = AnkiPreset(name: "Default", desiredRetention: 0.9, leech: .init(threshold: 5, action: .suspend))
        let taken = try #require(AnkiImport(notes: [.init(front: "a", back: "b", preset: 0)], presets: [stock]).deckOptions(applyingTo: LearningOptions()))
        #expect(taken.leechThreshold == 5 && taken.leechAction == .suspend)
        #expect(taken.targetRecall == LearningOptions().targetRecall)
        // The preset's FSRS settings come along.
        let fsrs = AnkiPreset(name: "a", parameters: Self.customSix, desiredRetention: 0.85, leech: .init(threshold: 3, action: .keep))
        let both = try #require(AnkiImport(notes: [.init(front: "a", back: "b", preset: 0)], presets: [fsrs]).deckOptions(applyingTo: LearningOptions()))
        #expect(both.targetRecall == 0.85 && both.leechThreshold == 3 && both.leechAction == .keep)
        // A preset with neither gives nothing; a threshold out of range is kept in it.
        let none = AnkiImport(notes: [.init(front: "a", back: "b", preset: 0)], presets: [AnkiPreset(name: "Default", desiredRetention: 0.9)])
        #expect(none.deckOptions(applyingTo: LearningOptions()) == nil)
        let wild = AnkiPreset(name: "a", leech: .init(threshold: 500, action: .keep))
        #expect(wild.learningOptions(applyingLeechTo: LearningOptions())?.leechThreshold == 99)
    }

    // MARK: Packages made by Anki

    private static func package(_ name: String) throws -> AnkiImport {
        let url = try #require(Bundle.module.url(forResource: "Resources/Anki/\(name)", withExtension: "apkg"))
        return try AnkiImport.read(url)
    }

    /// The values `make_anki_fixtures.py` gives the preset "Greek FSRS".
    static let greek: [Float] = [
        0.3178, 1.4204, 3.1073, 9.3125, 6.0231, 0.9166, 3.2872, 0.0010, 1.7841, 0.1502, 0.8873,
        1.5340, 0.0580, 0.2487, 1.5792, 0.5538, 1.8995, 0.6270, 0.1024, 0.0701, 0.1730,
    ]

    @Test(arguments: ["greek-latest", "greek-latest-cli", "greek-legacy2", "greek-legacy1"])
    func readsThePresetOfAPackageMadeByAnki(name: String) throws {
        let result = try Self.package(name)
        // Anki's stock leech settings: threshold 8, tag only. Those of a package Anki made prove the field numbers.
        #expect(result.presets == [AnkiPreset(name: "Greek FSRS", parameters: Self.greek, desiredRetention: 0.85, leech: .init(threshold: 8, action: .keep))])
        #expect(result.notes.allSatisfy { $0.preset == 0 })
        let options = try #require(result.learningOptions(applyingTo: LearningOptions()))
        #expect(options.targetRecall == 0.85)
        #expect(options.parameters.weights == Self.greek.map { Double("\($0)")! })
    }

    /// Two decks with presets of FSRS-5 (two cards) and FSRS-4.5 (one card), and one in the stock preset.
    @Test(arguments: ["presets-latest", "presets-legacy2"])
    func readsOlderParameterSetsOfAPackageMadeByAnki(name: String) throws {
        let result = try Self.package(name)
        #expect(result.notes.map(\.front) == ["ένα", "δύο", "τρία", "τέσσερα"])
        // In the order of Anki's IDs: the stock preset, then the two made for the decks.
        #expect(result.presets.map(\.name) == ["Default", "Five", "Four"])
        #expect(result.notes.map(\.preset) == [1, 1, 2, 0])
        #expect(result.presets[0].parameters.isEmpty && result.presets[0].desiredRetention == 0.9)
        #expect(result.presets[1].parameters.count == 19 && result.presets[1].desiredRetention == 0.95)
        #expect(result.presets[2].parameters.count == 17 && result.presets[2].desiredRetention == 0.8)
        #expect(result.dominantPreset?.name == "Five")

        let options = try #require(result.learningOptions(applyingTo: LearningOptions()))
        #expect(options.targetRecall == 0.95)
        #expect(options.parameters.weights.count == 21 && options.parameters.indexOutOfRange == nil)
        #expect(options.parameters.weights[20] == 0.5)
        #expect(options.parameters.weights[0] == 0.40255)
        // The 17 values of the other preset give a FSRS-6 set, too: w4 + 2 * w5 = 5.1618 + 2 * 1.2298.
        #expect(abs(try #require(result.presets[2].fsrsParameters)[4] - 7.6214) < 1e-5)
    }
}
