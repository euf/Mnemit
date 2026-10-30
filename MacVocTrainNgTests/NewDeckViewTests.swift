import Testing

@testable import MacVocTrain

/// When the New Deck sheet lets the learner create: with a name that can make a file, as the iPhone's sheet does.
@MainActor
struct NewDeckViewTests {
    @Test func createStaysOffUntilTheNameCanMakeAFile() {
        #expect(!NewDeckView(onCreate: { _ in }).canCreate)
        #expect(!NewDeckView(name: "   ", onCreate: { _ in }).canCreate)
        #expect(!NewDeckView(name: "Greek/B1", onCreate: { _ in }).canCreate)
        #expect(NewDeckView(name: "Greek B1", onCreate: { _ in }).canCreate)
    }
}
