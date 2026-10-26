import Foundation

extension DeckChange {
    /// Merges `other`, another version of the same deck, into `deck`, e.g. a version
    /// iCloud Drive kept apart after a conflict; `nil` if `deck` holds all of it already.
    /// Both apps edit cards, so each part of the deck has its own rule, and none of them
    /// takes a change of one device away for a change of the other.
    ///
    /// - The cards of both versions are kept. The order is that of the version with the
    ///   later `contentModified`, or of `deck` if they are the same, followed by the
    ///   cards only the other version holds.
    /// - A card deleted in one version (`Deck.deletedCards`) and still in the other is
    ///   deleted, unless something was done to it after the deletion:
    ///   edited, reset, suspended or resumed, reviewed (`Card.lastChange`). A card
    ///   the other version changed later than the deletion stays, so a review never
    ///   gets lost; with the same time, too.
    /// - The reviews of a deleted card stay: the retired cards (`Deck.retiredCards`) of both versions
    ///   are joined by ID, their logs like those of a card, and a card the rule above deletes
    ///   is retired with its log joined to the one the other version retired, if it did. A card that stays
    ///   takes the log its retired version holds, so a review never gets lost that way either.
    /// - The texts, the media, the note and the kind of a card come from the version that
    ///   changed them last (`Card.contentChanged`), or, with the same stamp or none, from the
    ///   version with the later `contentModified`.
    /// - The media files of both versions are joined: a file is named by its content and never
    ///   changes, so taking the files the other `media` folder holds and this one lacks is all
    ///   there is to it (`Deck.media`). Only those a card of the merged deck names come: a file
    ///   whose card is gone is an orphan, as in a package, and never makes a merge change anything.
    /// - The learning options come from the version that changed them last
    ///   (`Deck.learningOptionsChanged`), or likewise from the later `contentModified`.
    /// - The review logs of a card are joined. A review in both versions, at the same
    ///   second with the same grade, counts once, with the duration either version holds.
    /// - A card's reviews before its latest reset (`Card.learningStateReset`) drop out:
    ///   a version that hasn't seen the reset counts as a new card with only the
    ///   reviews since, replayed from scratch (#273).
    /// - The learning state of a card comes from the version that holds all its
    ///   reviews, replayed with the parameters of the
    ///   learning options if they differ there (`Scheduler.replayingMemory(of:)`). If each version has reviews the other
    ///   lacks, the joined log is replayed from scratch (`Scheduler.replaying(_:of:)`);
    ///   if it doesn't reach back to the first review, see `continuing`.
    /// - Whether a card is suspended comes from the version that suspended or resumed it
    ///   last (`Card.suspensionChanged`), or from the content's if both did so at the
    ///   same second. Suspending is not content, as the iPhone suspends cards too (#290).
    /// - The progress joins the days of both versions; a day in both comes from the
    ///   one with more days. Applying the change records the snapshot of its day anew.
    ///
    /// Merging `deck` into `other` gives the same deck, but for the fractions of a
    /// second of reviews both versions hold (`reviews.jsonl` keeps whole seconds), and
    /// for what is stamped the same in both versions but differs. That happens only to
    /// versions last changed by an app version without the stamps.
    ///
    /// - Parameter calendar: Counts study days for replaying, and should be the one
    ///   other devices use, so they all replay a log to the same learning state.
    public static func merging(_ other: Deck, into deck: Deck, calendar: StudyCalendar) -> DeckChange? {
        let otherHasContent = (other.contentModified ?? .distantPast) > (deck.contentModified ?? .distantPast)
        let (first, second) = otherHasContent ? (other, deck) : (deck, other)
        let otherChangedOptions = (other.learningOptionsChanged ?? .distantPast) > (deck.learningOptionsChanged ?? .distantPast)
        let sameOptionsStamp = other.learningOptionsChanged == deck.learningOptionsChanged
        let learningOptions = (otherChangedOptions || (sameOptionsStamp && otherHasContent)) ? other.learningOptions : deck.learningOptions
        let scheduler = Scheduler(learningOptions: learningOptions, calendar: calendar)
        let mine = Dictionary(deck.cards.map { ($0.id, $0) }) { first, _ in first }
        let theirs = Dictionary(other.cards.map { ($0.id, $0) }) { first, _ in first }
        let inFirst = Set(first.cards.map(\.id))

        func join(_ mine: Card, _ theirs: Card) -> Card {
            merging(
                mine, and: theirs,
                mineModel: deck.learningOptions.parameters, theirsModel: other.learningOptions.parameters,
                otherHasContent: otherHasContent, scheduler: scheduler
            )
        }
        let retiredMine = Dictionary(deck.retiredCards.map { ($0.id, $0) }) { first, _ in first }
        let retiredTheirs = Dictionary(other.retiredCards.map { ($0.id, $0) }) { first, _ in first }

        var change = DeckChange(contentStamp: .keep)
        var kept = Set<Card.ID>()
        var named = Set<String>()
        var dropped: [(card: Card, isMine: Bool)] = []
        for card in first.cards + second.cards.filter({ !inFirst.contains($0.id) }) {
            let merged: Card
            switch (mine[card.id], theirs[card.id]) {
            case let (mine?, theirs?):
                merged = join(mine, theirs)
            case let (only?, nil), let (nil, only?):
                // Only one version holds it: it is deleted in the other, or new in this one.
                let isMine = mine[card.id] != nil
                let deletion = (isMine ? other : deck).deletedCards[card.id]
                if let deletion, deletion > only.lastChange {
                    dropped.append((only, isMine))
                    continue
                }
                // A card that stays takes the reviews its deletion kept.
                merged = (isMine ? retiredTheirs : retiredMine)[card.id].map { isMine ? join(only, $0) : join($0, only) } ?? only
            case (nil, nil):
                continue
            }
            if let existing = mine[card.id] {
                if merged != existing { change.upserts.append((merged, nil)) }
            } else {
                // At its index among the cards kept, so the cards end up in the order.
                change.upserts.append((merged, kept.count))
            }
            kept.insert(card.id)
            named.formUnion(merged.media.names)
        }
        change.removals = deck.cards.map(\.id).filter { !kept.contains($0) }
        change.addedMedia = other.media.missing(from: deck.media).keeping(named)

        var deleted = deck.deletedCards
        for (id, date) in other.deletedCards {
            deleted[id] = max(deleted[id] ?? .distantPast, date)
        }
        for id in kept {
            deleted[id] = nil
        }

        // The retired cards of both versions and the cards dropped now, joined by ID, those that stay out.
        var pool: [Card.ID: (mine: Card?, theirs: Card?)] = [:]
        var order: [Card.ID] = []
        func add(_ card: Card, isMine: Bool) {
            if pool[card.id] == nil { order.append(card.id) }
            if isMine { pool[card.id, default: (nil, nil)].mine = card } else { pool[card.id, default: (nil, nil)].theirs = card }
        }
        for card in deck.retiredCards { add(card, isMine: true) }
        for card in other.retiredCards { add(card, isMine: false) }
        for (card, isMine) in dropped { add(card, isMine: isMine) }
        let retired: [Card] = order.compactMap { id in
            guard !kept.contains(id), let versions = pool[id] else { return nil }
            let card: Card
            switch (versions.mine, versions.theirs) {
            case let (mine?, theirs?): card = join(mine, theirs)
            case let (only?, nil), let (nil, only?): card = only
            case (nil, nil): return nil
            }
            return card.log.isEmpty ? nil : card
        }

        if learningOptions != deck.learningOptions {
            change.learningOptions = learningOptions
        }
        let contentModified = [deck.contentModified, other.contentModified].compactMap { $0 }.max()
        let optionsChanged = [deck.learningOptionsChanged, other.learningOptionsChanged].compactMap { $0 }.max()
        if contentModified != deck.contentModified || optionsChanged != deck.learningOptionsChanged {
            change.contentStamp = .set(contentModified, learningOptions: optionsChanged)
        }
        let progress = joinedProgress(deck.progress, other.progress, preferringFirst: !otherHasContent)
        if progress != deck.progress {
            change.progress = progress
        }

        if case .keep = change.contentStamp, change.upserts.isEmpty, change.removals.isEmpty, change.learningOptions == nil, change.progress == nil, change.addedMedia.isEmpty, deleted == deck.deletedCards, retired == deck.retiredCards {
            return nil
        }
        // Always set: undoing a merge must restore the deleted and retired cards, not note the
        // cards it takes back as deleted now.
        change.deletedCards = deleted
        change.retiredCards = retired
        return change
    }

    /// The card both versions hold: its content from the version that changed it last,
    /// its learning state and suspension joined.
    private static func merging(
        _ mine: Card, and theirs: Card,
        mineModel: FSRSParameters, theirsModel: FSRSParameters,
        otherHasContent: Bool, scheduler: Scheduler
    ) -> Card {
        let changedMine = mine.contentChanged ?? .distantPast
        let changedTheirs = theirs.contentChanged ?? .distantPast
        var merged = (changedTheirs > changedMine || (changedTheirs == changedMine && otherHasContent)) ? theirs : mine
        let learned = learning(
            of: Version(card: mine, model: mineModel, hasContent: !otherHasContent),
            and: Version(card: theirs, model: theirsModel, hasContent: otherHasContent),
            scheduler: scheduler
        )
        merged.learningState = learned.learningState
        merged.log = learned.log
        merged.learningStateReset = learned.learningStateReset
        let suspension = latestSuspension(of: mine, and: theirs, preferringMine: !otherHasContent)
        merged.isSuspended = suspension.isSuspended
        merged.suspensionChanged = suspension.suspensionChanged
        return merged
    }

    /// One version of a card in a merge.
    private struct Version {
        var card: Card
        /// The parameters its learning state was computed with.
        var model: FSRSParameters
        /// Whether its deck is the one the merge takes the content from.
        var hasContent: Bool
    }

    /// A review as a merge compares it: at whole seconds, as `reviews.jsonl` stores it.
    private struct ReviewKey: Hashable {
        var second: Int
        var grade: Grade

        init(_ entry: ReviewLogEntry) {
            second = Int(entry.date.timeIntervalSince1970.rounded(.down))
            grade = entry.grade
        }
    }

    /// Of both versions of a card, the one that suspended or resumed it last; if both
    /// did so at the same time, or neither ever did, `mine` if `preferringMine`.
    private static func latestSuspension(of mine: Card, and theirs: Card, preferringMine: Bool) -> Card {
        let changedMine = mine.suspensionChanged ?? .distantPast
        let changedTheirs = theirs.suspensionChanged ?? .distantPast
        if changedMine == changedTheirs {
            return preferringMine ? mine : theirs
        }
        return changedMine > changedTheirs ? mine : theirs
    }

    /// The reviews of `log` that `others` lacks; a review in both counts once, but
    /// twice if one of them holds it twice.
    private static func reviews(of log: [ReviewLogEntry], missingFrom others: [ReviewLogEntry]) -> [ReviewLogEntry] {
        var remaining: [ReviewKey: Int] = [:]
        for entry in others {
            remaining[ReviewKey(entry), default: 0] += 1
        }
        return log.filter { entry in
            let key = ReviewKey(entry)
            guard let count = remaining[key], count > 0 else { return true }
            remaining[key] = count - 1
            return false
        }
    }

    /// The card of one of both versions, with the learning state and review log the
    /// merge gives it; its other properties don't count. A review without a duration
    /// takes the one the same review has in the other version, if it has one: the
    /// duration plays no part in the schedule or in whether two reviews are the same.
    private static func learning(of mine: Version, and theirs: Version, scheduler: Scheduler) -> Card {
        var card = joinedLearning(of: mine, and: theirs, scheduler: scheduler)
        card.log = fillingDurations(of: card.log, from: mine.card.log + theirs.card.log)
        return card
    }

    private static func fillingDurations(of log: [ReviewLogEntry], from others: [ReviewLogEntry]) -> [ReviewLogEntry] {
        guard log.contains(where: { $0.duration == nil }) else { return log }
        var durations: [ReviewKey: Duration] = [:]
        for entry in others {
            if let duration = entry.duration, durations[ReviewKey(entry)] == nil { durations[ReviewKey(entry)] = duration }
        }
        return log.map { entry in
            var filled = entry
            if filled.duration == nil { filled.duration = durations[ReviewKey(entry)] }
            return filled
        }
    }

    private static func joinedLearning(of mine: Version, and theirs: Version, scheduler: Scheduler) -> Card {
        let mine = resetting(mine, like: theirs.card, scheduler: scheduler)
        let theirs = resetting(theirs, like: mine.card, scheduler: scheduler)
        let onlyMine = reviews(of: mine.card.log, missingFrom: theirs.card.log)
        let onlyTheirs = reviews(of: theirs.card.log, missingFrom: mine.card.log)

        if onlyMine.isEmpty || onlyTheirs.isEmpty {
            // One version holds every review; with the same reviews, the content's.
            let complete: Version
            if onlyMine.isEmpty && onlyTheirs.isEmpty {
                complete = mine.hasContent ? mine : theirs
            } else {
                complete = onlyTheirs.isEmpty ? mine : theirs
            }
            guard complete.model != scheduler.learningOptions.parameters else { return complete.card }
            return scheduler.replayingMemory(of: complete.card) ?? complete.card
        }

        let joined = (mine.card.log + onlyTheirs).sorted { ($0.date, $0.grade) < ($1.date, $1.grade) }
        if mine.card.hasCompleteLog && theirs.card.hasCompleteLog {
            return scheduler.replaying(joined, of: mine.card)
        }
        return continuing(mine, theirs, scheduler: scheduler)
    }

    /// `version` after the reset of the learning state `other` holds, if `version`
    /// hasn't seen it: a new card again, with only the reviews since replayed. The
    /// version itself if its own reset is as late.
    private static func resetting(_ version: Version, like other: Card, scheduler: Scheduler) -> Version {
        guard let reset = other.learningStateReset, reset > version.card.learningStateReset ?? .distantPast else { return version }
        var card = scheduler.replaying(version.card.log.filter { $0.date >= reset }, of: version.card)
        card.learningStateReset = reset
        return Version(card: card, model: scheduler.learningOptions.parameters, hasContent: version.hasContent)
    }

    /// For logs that don't reach back to the first review, as after an import from
    /// MacVocTrain 1: continues the version whose last review is the earlier one with
    /// the reviews only the other holds (`Scheduler.review`). A review before the last
    /// one of the continued version only joins its log.
    private static func continuing(_ mine: Version, _ theirs: Version, scheduler: Scheduler) -> Card {
        let lastMine = mine.card.learningState?.lastReview ?? .distantPast
        let lastTheirs = theirs.card.learningState?.lastReview ?? .distantPast
        let mineFirst = lastMine < lastTheirs || (lastMine == lastTheirs && mine.hasContent)
        let (earlier, later) = mineFirst ? (mine.card, theirs.card) : (theirs.card, mine.card)

        var card = earlier
        let added = reviews(of: later.log, missingFrom: earlier.log).sorted { ($0.date, $0.grade) < ($1.date, $1.grade) }
        for entry in added {
            if var learningState = card.learningState, entry.date <= learningState.lastReview {
                // Counted, so the log stays no longer than the reviews (see `DeckFile`).
                learningState.reviews += 1
                card.learningState = learningState
                let index = card.log.firstIndex { $0.date > entry.date } ?? card.log.endIndex
                card.log.insert(entry, at: index)
            } else {
                var random = Scheduler.random(forReviewOf: card.id, at: entry.date)
                card = scheduler.review(card, grade: entry.grade, at: entry.date, mode: entry.mode, duration: entry.duration, using: &random)
            }
        }
        return card
    }

    /// The snapshots of both progresses by day, those of `first` for a day in both if
    /// it has more days or, with as many, if `preferringFirst`.
    private static func joinedProgress(_ first: [DailySnapshot], _ second: [DailySnapshot], preferringFirst: Bool) -> [DailySnapshot] {
        let firstWins = first.count > second.count || (first.count == second.count && preferringFirst)
        let (winner, other) = firstWins ? (first, second) : (second, first)
        var snapshots = Dictionary(other.map { ($0.day, $0) }) { _, last in last }
        for snapshot in winner {
            snapshots[snapshot.day] = snapshot
        }
        return snapshots.values.sorted { $0.day < $1.day }
    }
}
