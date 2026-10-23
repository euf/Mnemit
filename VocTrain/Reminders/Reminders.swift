import Foundation
import Observation
import UIKit
import UserNotifications
import VocabCore

/// When the daily reminder fires and what it says, apart from the notification center.
enum ReminderPlan {
    /// How many days ahead the reminders are scheduled: the app may stay closed for a while,
    /// and each day's reminder carries the counts that day will have.
    static let days = 7

    /// The next `count` moments at `minutes` after midnight, the first one still ahead of `now`.
    static func fireDates(after now: Date, minutes: Int, count: Int = days, calendar: Calendar = .current) -> [Date] {
        guard let first = calendar.nextDate(after: now, matching: DateComponents(hour: minutes / 60, minute: minutes % 60), matchingPolicy: .nextTime) else { return [] }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    /// What a reminder says, in the words of Today: the streak it keeps, "Keep your 12-day streak", and the streak
    /// step, "≈ 2 min is enough."; without a streak, a start. `nil` when no deck has cards, and then no reminder is
    /// due either. A count of the cards due, which after a break can be hundreds, is never in it.
    static func content(_ decks: [(name: String, total: Int)], streak: Int) -> (title: String, body: String)? {
        guard decks.contains(where: { $0.total > 0 }) else { return nil }
        guard streak > 0 else { return (String(localized: "Time to study"), String(localized: "≈ 2 min is enough to start.")) }
        return (String(localized: "Keep your \(streak)-day streak"), String(localized: "≈ 2 min is enough."))
    }

    /// The number on the icon: the cards left to close today's ring, as Today's headline counts them, never the whole
    /// plan; 0 once the ring is closed. Without the ring's figures, the cards due.
    static func badge(due: Int, progress: DailyProgress?) -> Int {
        guard let ring = progress?.ring, ring.goal > 0 else { return due }
        return min(due, max(0, ring.goal - ring.done))
    }
}

/// The daily reminder to study: a local notification at the learner's time with the streak it keeps, and the number
/// on the app icon, the cards left to close today's ring (`ReminderPlan`).
/// Local notifications only; the app has no push entitlement.
///
/// The reminders of the next few days are scheduled at once, each with the counts of its
/// own day (`StudySession.counts(for:at:calendar:newCardAllowance:)`, so cards that come due until
/// then are in, and the new ones are those of today's allowance), and again whenever the counts may have changed: when the app goes to the
/// background, after a deck closes, when the learner changes the time and when the app
/// comes to the front. A day with nothing due gets no reminder.
@MainActor @Observable
final class Reminders {
    static let enabledKey = "ReminderEnabled"
    static let minutesKey = "ReminderMinutes"
    /// 09:00, in minutes after midnight.
    static let defaultMinutes = 9 * 60

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    /// The time of the reminder, in minutes after midnight.
    var minutes: Int {
        didSet { defaults.set(minutes, forKey: Self.minutesKey) }
    }

    /// What the learner allowed in the system dialog, or in the iOS settings after it.
    private(set) var status = UNAuthorizationStatus.notDetermined

    /// When the next reminder fires, `nil` if none is scheduled: the reminder is off, not allowed,
    /// or no day ahead has anything due. The widget shows it.
    private(set) var nextFire: Date?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let center: UNUserNotificationCenter
    /// The last run; the next one waits for it, so an older run never overwrites a newer one.
    @ObservationIgnored private var lastRun: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, center: UNUserNotificationCenter = .current()) {
        self.defaults = defaults
        self.center = center
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        minutes = defaults.object(forKey: Self.minutesKey) as? Int ?? Self.defaultMinutes
    }

    /// The time of day as a date, for a time picker; the day is today's and doesn't matter.
    var time: Date {
        get { Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date() }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    /// Whether the learner allows notifications at all.
    var isAllowed: Bool {
        status == .authorized || status == .provisional
    }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    /// Asks the system for the permission to notify, with the badge and the sound; the
    /// dialog shows only the first time. Returns whether the learner allowed it.
    func requestAuthorization() async -> Bool {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshStatus()
        return isAllowed
    }

    /// Schedules the reminders for `decks` and sets the number on the app icon; takes away
    /// both when the reminder is off. `open` is the deck that is open now: its counts come
    /// from the document, which holds changes the file doesn't yet.
    func reschedule(decks: [KnownDeck], open: OpenDeck?, progress: DailyProgress? = nil) async {
        let previous = lastRun
        let run = Task { @MainActor in
            await previous?.value
            await schedule(decks: decks, open: open, progress: progress, now: Date())
        }
        lastRun = run
        await run.value
    }

    /// Like `reschedule(decks:open:)`, for the moment the app goes to the background: iOS
    /// gets asked for the time to finish, as it suspends the app soon after.
    func rescheduleBeforeSuspending(decks: [KnownDeck], open: OpenDeck?, progress: DailyProgress? = nil) {
        let time = BackgroundTime()
        time.identifier = UIApplication.shared.beginBackgroundTask(withName: "Reminders") { [time] in
            MainActor.assumeIsolated { time.end() }
        }
        Task {
            await reschedule(decks: decks, open: open, progress: progress)
            time.end()
        }
    }

    private static let identifiers = (0..<ReminderPlan.days).map { "daily-reminder-\($0)" }

    private func schedule(decks: [KnownDeck], open: OpenDeck?, progress: DailyProgress?, now: Date) async {
        center.removePendingNotificationRequests(withIdentifiers: Self.identifiers)
        await refreshStatus()
        guard isEnabled, isAllowed else {
            nextFire = nil
            await setBadge(0)
            return
        }

        // Now, for the number on the icon, then the moment of each reminder.
        let fires = ReminderPlan.fireDates(after: now, minutes: minutes)
        let dates = [now] + fires
        var days = Array(repeating: [(name: String, total: Int)](), count: dates.count)
        for deck in decks {
            guard let counts = await counts(of: deck, on: dates, open: open) else { continue }
            for (day, count) in counts.enumerated() {
                days[day].append((deck.name, count.total))
            }
        }
        await setBadge(ReminderPlan.badge(due: days[0].reduce(0) { $0 + $1.total }, progress: progress))

        var first: Date?
        for (index, fire) in fires.enumerated() {
            let day = days[index + 1]
            // A streak holds through one missed day; a reminder further ahead than that names none.
            let streak = index < 2 ? progress?.streak.days ?? 0 : 0
            guard let text = ReminderPlan.content(day, streak: streak) else { continue }
            first = first ?? fire
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default
            // That day's ring is about the size of today's.
            let due = day.reduce(0) { $0 + $1.total }
            content.badge = NSNumber(value: progress.map { $0.ring.goal > 0 ? min(due, $0.ring.goal) : due } ?? due)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.identifiers[index], content: content, trigger: trigger))
        }
        nextFire = first
    }

    private func counts(of deck: KnownDeck, on dates: [Date], open: OpenDeck?) async -> [StudyCounts]? {
        if let open, KnownDecks.isSameFile(open.url, deck.url), let document = open.document {
            // A paused deck asks nothing of the day.
            guard !document.deck.learningOptions.isPaused else { return nil }
            let allowance = document.newCardAllowance
            return dates.map { StudySession.counts(for: document.deck, at: $0, calendar: document.calendar, newCardAllowance: allowance) }
        }
        let url = deck.url
        let allowance = NewCardAllowances.today[url]
        return await Task.detached(priority: .utility) { KnownDeckCounts.counts(at: url, on: dates, allowance: allowance) }.value
    }

    private func setBadge(_ count: Int) async {
        try? await center.setBadgeCount(count)
    }
}

/// A claim on background time from iOS, ended once the work is done or the time is up.
@MainActor
final class BackgroundTime {
    var identifier = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
