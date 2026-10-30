import Foundation

/// Writes and reads `reviews.jsonl`, the review log of a deck package.
///
/// Each line is one review, grouped by card in deck order:
///
/// ```
/// {"card":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":1791216000,"grade":3}
/// {"card":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":1791302400,"grade":3,"mode":"revealed","ms":4210}
/// {"card":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":1791388800,"grade":1,"undone":true}
/// ```
///
/// A line with `"undone":true` is a review the learner took back (`Card.undone`), not part of the log: it keeps a merge
/// from bringing the review back from a copy of the deck that saw it. They follow the card's other lines.
/// `date` is in whole seconds since 1970. `mode` is left out for a typed review, and
/// a missing or unknown one is read as typed: every review before it came was typed.
/// `ms` is how long the card was on screen, in whole milliseconds (`ReviewLogEntry.duration`),
/// left out where it wasn't measured. The encoder keeps the encoded lines of
/// every card and on the next call only encodes what changed, so encoding costs the
/// same however long the log gets. Joining the lines and writing `reviews.jsonl`
/// still grow with the log, but stay cheap. A card's lines are reused while its
/// log is the one encoded (an array that shares its storage compares in constant time),
/// and extended when entries were appended; any other change, a reset, an undo, a merge
/// that filled in a duration, encodes the card's lines anew.
public final class ReviewLogEncoder: @unchecked Sendable {
    private struct Chunk {
        /// The log the lines of `data` encode.
        var log: [ReviewLogEntry]
        var data: Data
        var undone: [ReviewKey]
        var undoneData: Data
    }

    // Saving runs on a background thread; the lock guards the cache.
    private let lock = NSLock()
    private var chunks: [Card.ID: Chunk] = [:]
    private var encodedCardCount = 0

    public init() {}

    /// Cards whose lines were encoded or extended by the last call to `encode`.
    var lastEncodedCardCount: Int {
        lock.withLock { encodedCardCount }
    }

    public func encode(_ cards: [Card]) -> Data {
        lock.withLock {
            var result = Data()
            var newChunks: [Card.ID: Chunk] = [:]
            newChunks.reserveCapacity(chunks.count)
            var encoded = 0

            for card in cards where !card.log.isEmpty || !card.undone.isEmpty {
                var chunk = chunks[card.id] ?? Chunk(log: [], data: Data(), undone: [], undoneData: Data())
                if chunk.log != card.log || chunk.undone != card.undone {
                    if !chunk.log.isEmpty, card.log.count > chunk.log.count, card.log.starts(with: chunk.log) {
                        Self.appendLines(for: card, entries: card.log[chunk.log.count...], to: &chunk.data)
                    } else if chunk.log != card.log {
                        chunk.data = Data()
                        Self.appendLines(for: card, entries: card.log[...], to: &chunk.data)
                    }
                    if chunk.undone != card.undone {
                        chunk.undoneData = Data()
                        Self.appendUndone(for: card, to: &chunk.undoneData)
                    }
                    chunk.log = card.log
                    chunk.undone = card.undone
                    encoded += 1
                }
                newChunks[card.id] = chunk
                result.append(chunk.data)
                result.append(chunk.undoneData)
            }

            chunks = newChunks
            encodedCardCount = encoded
            return result
        }
    }

    private static func appendLines(for card: Card, entries: ArraySlice<ReviewLogEntry>, to data: inout Data) {
        // Formatted by hand: a UUID and integers need no escaping, and a JSONEncoder
        // per line would cost more than the rest of the save.
        let id = card.id.uuidString
        for entry in entries {
            let seconds = Int(entry.date.timeIntervalSince1970.rounded(.down))
            let mode = entry.mode == .revealed ? ",\"mode\":\"revealed\"" : ""
            let duration = entry.duration.map { ",\"ms\":\(Int(($0 / .milliseconds(1)).rounded()))" } ?? ""
            data.append(contentsOf: "{\"card\":\"\(id)\",\"date\":\(seconds),\"grade\":\(entry.grade.rawValue)\(mode)\(duration)}\n".utf8)
        }
    }

    private static func appendUndone(for card: Card, to data: inout Data) {
        for key in card.undone {
            data.append(contentsOf: "{\"card\":\"\(card.id.uuidString)\",\"date\":\(key.second),\"grade\":\(key.grade.rawValue),\"undone\":true}\n".utf8)
        }
    }

    private struct Line: Decodable {
        var card: UUID
        var date: Int
        var grade: Grade
        var mode: String?
        var ms: Int?
        var undone: Bool?

        var entry: ReviewLogEntry {
            ReviewLogEntry(date: Date(timeIntervalSince1970: Double(date)), grade: grade, mode: mode == "revealed" ? .revealed : .typed, duration: ms.map { .milliseconds($0) })
        }
    }

    /// Replaces the review logs of `cards` with the ones in `data`. A line of a card
    /// that isn't among `cards` is an error: the app never writes one.
    static func attach(_ data: Data, to cards: inout [Card]) throws {
        let lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
            .enumerated()
            .filter { !$0.element.allSatisfy { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\r") } }

        var logs: [Card.ID: [ReviewLogEntry]] = [:]
        var undone: [Card.ID: [ReviewKey]] = [:]
        let decoder = JSONDecoder()
        // One decoder call for the whole file is much faster than one per line.
        var array = Data("[".utf8)
        for (index, line) in lines.enumerated() {
            if index > 0 { array.append(UInt8(ascii: ",")) }
            array.append(contentsOf: line.element)
        }
        array.append(UInt8(ascii: "]"))

        let decoded: [Line]
        do {
            decoded = try decoder.decode([Line].self, from: array)
        } catch {
            // Find the culprit so the error can name it.
            for (number, line) in lines where (try? decoder.decode(Line.self, from: Data(line))) == nil {
                throw DeckFile.Error.damagedReviewLog(line: number + 1)
            }
            throw DeckFile.Error.damagedReviewLog(line: 0)
        }

        let ids = Set(cards.map(\.id))
        for (index, line) in decoded.enumerated() {
            guard ids.contains(line.card) else {
                throw DeckFile.Error.reviewsOfUnknownCard(line: lines[index].offset + 1)
            }
            if line.undone == true {
                undone[line.card, default: []].append(ReviewKey(line.entry))
            } else {
                logs[line.card, default: []].append(line.entry)
            }
        }
        for index in cards.indices {
            cards[index].log = logs[cards[index].id] ?? []
            cards[index].undone = Set(undone[cards[index].id] ?? []).sorted()
        }
    }
}
