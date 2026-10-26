import Foundation
import Testing

@testable import MacVocTrain

struct PreferencesTests {
    /// Launch opens no decks of the last run, also for a learner whose older version stored the preference as on.
    @Test(arguments: [nil, true, false])
    func launchReopensNoDecks(stored: Bool?) throws {
        let domain = "PreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        if let stored { defaults.set(stored, forKey: Preferences.reopenDecksKey) }

        Preferences.setUpDefaults(defaults)

        #expect(defaults.persistentDomain(forName: domain)?[Preferences.reopenDecksKey] as? Bool == false)
    }
}
