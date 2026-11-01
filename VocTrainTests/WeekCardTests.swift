import ImageIO
import Testing

@testable import VocTrain
@testable import VocabCore

/// The week's card that Progress shares is a PNG of the card at 3×.
@MainActor
struct WeekCardTests {
    @Test func theSharedCardIsAPNGOfTheCard() throws {
        let progress = DailyProgress(
            ring: DailyRing(done: 0, goal: 10), streak: Streak(days: 12, repairCards: nil),
            learned: WordsLearned(words: 412, wordsAtDayStart: 400), wordsRight: WordsRight(words: 184, secondsPerAnswer: 8.2, bestBefore: 150))
        let data = try WeekCardImage(card: WeekCard(progress: progress, calendar: StudyCalendar())).png()
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 440 * 3)
        #expect(image.height > 200 * 3)
    }
}
