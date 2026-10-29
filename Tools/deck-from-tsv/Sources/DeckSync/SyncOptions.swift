import Foundation
import VocabCore

/// A session limit as typed on the command line: a number, or "none" for unlimited.
public enum SyncLimit: Equatable, Sendable {
    case count(Int)
    case unlimited

    init(argument: String, flag: String, range: ClosedRange<Int>) throws {
        if argument.lowercased() == "none" {
            self = .unlimited
        } else if let count = Int(argument), range.contains(count) {
            self = .count(count)
        } else {
            throw SyncError("\(flag) takes a number from \(range.lowerBound) to \(range.upperBound), or none")
        }
    }

    var value: Int? {
        if case let .count(count) = self { count } else { nil }
    }
}

/// The learning options a run sets; every option left `nil` keeps the deck's value.
public struct OptionOverrides: Equatable, Sendable {
    public var newPerSession: SyncLimit?
    public var newProductionPerSession: SyncLimit?
    public var unlockDays: Int?

    public init() {}

    func applied(to options: LearningOptions) -> LearningOptions {
        var options = options
        if let newPerSession { options.newCardsPerSession = newPerSession.value }
        if let newProductionPerSession { options.newProductionPerSession = newProductionPerSession.value }
        if let unlockDays { options.productionUnlockDays = unlockDays }
        return options
    }

    /// The options that differ between `before` and `after`, one line each.
    static func changes(from before: LearningOptions, to after: LearningOptions) -> [String] {
        func limit(_ value: Int?) -> String { value.map(String.init) ?? "none" }
        var lines: [String] = []
        if before.newCardsPerSession != after.newCardsPerSession {
            lines.append("new per session \(limit(before.newCardsPerSession)) → \(limit(after.newCardsPerSession))")
        }
        if before.newProductionPerSession != after.newProductionPerSession {
            lines.append("new production per session \(limit(before.newProductionPerSession)) → \(limit(after.newProductionPerSession))")
        }
        if before.productionUnlockDays != after.productionUnlockDays {
            lines.append("unlock days \(before.productionUnlockDays) → \(after.productionUnlockDays)")
        }
        return lines
    }
}

/// The command line of `deck-from-tsv`.
public struct SyncOptions: Equatable, Sendable {
    public var input: URL
    public var deck: URL
    public var dryRun = false
    public var suspendMissing = false
    public var backupDirectory: URL?
    public var overrides = OptionOverrides()
    /// A file of word keys (`Card.note`), one per line: their new cards join the run's addition in that
    /// order, after the run's other changes (`DeckChange.renewing(_:in:at:)`).
    public var renew: URL?

    public static let usage = """
        usage: deck-from-tsv <cards.tsv> <deck.mnemit | deck.voctrain> [--dry-run] [--suspend-missing] [--backup-dir DIR]
                             [--new-per-session N|none] [--new-production-per-session N|none]
                             [--unlock-days N] [--renew NOTES]
        --new-per-session and --new-production-per-session keep their names; the limits hold per study day.
        --renew NOTES: the new cards of the word keys in the file, one per line, become today's addition in that
        order and come first among the new cards.
        """

    /// - Parameter arguments: The command line without the program name.
    /// - Throws: `SyncError` with the reason, for the usage line to follow.
    public static func parse(_ arguments: [String]) throws -> SyncOptions {
        var positional: [String] = []
        var dryRun = false
        var suspendMissing = false
        var backupDirectory: URL?
        var overrides = OptionOverrides()
        var renew: URL?

        var remaining = arguments[...]
        func value(of flag: String) throws -> String {
            guard let next = remaining.popFirst() else { throw SyncError("\(flag) needs a value") }
            return next
        }
        while let argument = remaining.popFirst() {
            switch argument {
            case "--dry-run": dryRun = true
            case "--suspend-missing": suspendMissing = true
            case "--backup-dir": backupDirectory = URL(fileURLWithPath: try value(of: argument))
            case "--new-per-session":
                overrides.newPerSession = try SyncLimit(argument: try value(of: argument), flag: argument, range: LearningOptions.sessionLimitRange)
            case "--new-production-per-session":
                overrides.newProductionPerSession = try SyncLimit(argument: try value(of: argument), flag: argument, range: LearningOptions.productionLimitRange)
            case "--unlock-days":
                let days = try value(of: argument)
                guard let count = Int(days), LearningOptions.productionUnlockDaysRange.contains(count) else {
                    throw SyncError("\(argument) takes a number from 0 to \(LearningOptions.productionUnlockDaysRange.upperBound)")
                }
                overrides.unlockDays = count
            case "--renew": renew = URL(fileURLWithPath: try value(of: argument))
            default:
                if argument.hasPrefix("--") { throw SyncError("unknown option \(argument)") }
                positional.append(argument)
            }
        }

        // The former third argument, new cards per session, still works.
        if positional.count == 3, overrides.newPerSession == nil {
            overrides.newPerSession = try SyncLimit(argument: positional[2], flag: "the third argument", range: LearningOptions.sessionLimitRange)
            positional.removeLast()
        }
        guard positional.count == 2 else { throw SyncError("expected a TSV and a deck") }
        return SyncOptions(
            input: URL(fileURLWithPath: positional[0]), deck: URL(fileURLWithPath: positional[1]), dryRun: dryRun,
            suspendMissing: suspendMissing, backupDirectory: backupDirectory, overrides: overrides, renew: renew)
    }
}
