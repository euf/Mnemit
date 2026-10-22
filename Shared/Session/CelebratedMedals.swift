import Foundation
import VocabCore

/// The medals this device has celebrated, so a medal is celebrated once: as a toast in the study stream the
/// moment it is earned, on the rest, or as "New medals" on Today when it was earned on another device. In
/// `UserDefaults`, key `CelebratedMedals`, a list of `"<kind key>@<study day>"` (`AchievementKind.key`).
///
/// The first read, with no key yet, marks every achievement from before today as celebrated without a word,
/// so an update that brings the store doesn't greet the learner with all their history. Under test the store
/// is in memory.
@MainActor
final class CelebratedMedals {
    static let defaultsKey = "CelebratedMedals"
    static let shared = CelebratedMedals(defaults: GreekSpeech.isUnderTest ? nil : .standard)

    private let defaults: UserDefaults?
    /// `nil` before the first read.
    private var keys: Set<String>?

    /// - Parameter defaults: Where the keys live; `nil` keeps them in memory.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        keys = defaults?.stringArray(forKey: Self.defaultsKey).map(Set.init)
    }

    static func key(of achievement: Achievement) -> String {
        "\(achievement.kind.key)@\(achievement.day)"
    }

    /// What of `achievements` is not celebrated yet, oldest first. `today` is the study day, for the first read.
    func pending(_ achievements: [Achievement], today: Int) -> [Achievement] {
        let known = keys ?? Set(achievements.filter { $0.day < today }.map(Self.key(of:)))
        if keys == nil { save(known) }
        return achievements.filter { !known.contains(Self.key(of: $0)) }
    }

    func mark(_ achievements: [Achievement]) {
        guard !achievements.isEmpty else { return }
        save((keys ?? []).union(achievements.map(Self.key(of:))))
    }

    /// Marks what was earned on `today` as celebrated, for the rest, which shows it. Reads first, so the
    /// first read still marks the past.
    func markToday(in achievements: [Achievement], today: Int) {
        _ = pending(achievements, today: today)
        mark(achievements.filter { $0.day == today })
    }

    private func save(_ new: Set<String>) {
        keys = new
        defaults?.set(new.sorted(), forKey: Self.defaultsKey)
    }
}
