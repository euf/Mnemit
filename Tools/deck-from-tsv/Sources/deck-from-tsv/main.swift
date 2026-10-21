import Foundation
import VocabCore

// deck-from-tsv <cards.tsv> <deck.voctrain> [new-cards-per-session]
//
// Rows are question, answer, optional hint, as for File → Import Cards in the Mac app.
// An existing deck keeps its cards, reviews and options; only rows whose question it
// lacks are added, so the tool can run again whenever the TSV grows.

let arguments = CommandLine.arguments
guard arguments.count == 3 || arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: deck-from-tsv <cards.tsv> <deck.voctrain> [new-cards-per-session]\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
let now = Date()
let calendar = StudyCalendar()

var deck = Deck()
if FileManager.default.fileExists(atPath: output.path) {
    deck = try DeckFile.decode(FileWrapper(url: output))
}
let before = deck.cards.count

let (rows, _) = DelimitedText.decode(try Data(contentsOf: input))
let result = CardImporter.candidates(from: rows, existing: deck.cards, isHeader: { _ in false }, created: now)
let fresh = result.candidates.filter { $0.duplicate == nil }.map(\.card)
if let change = DeckChange.adding(fresh, to: deck) {
    _ = deck.apply(change, at: now, calendar: calendar)
}
if arguments.count == 4, let perSession = Int(arguments[3]) {
    var options = deck.learningOptions
    options.newCardsPerSession = perSession
    if let change = DeckChange.changingLearningOptions(options, in: deck, calendar: calendar) {
        _ = deck.apply(change, at: now, calendar: calendar)
    }
}

try DeckFile.fileWrapper(for: deck).write(to: output, options: .atomic, originalContentsURL: nil)
print("\(output.lastPathComponent): \(before) → \(deck.cards.count) cards, \(fresh.count) added, \(result.candidates.count - fresh.count) duplicates and \(result.skippedRows) empty rows skipped")
