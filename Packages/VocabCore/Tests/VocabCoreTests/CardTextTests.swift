import Testing
import VocabCore

struct CardTextTests {
    @Test func trimsSurroundingWhitespace() throws {
        let text = try #require(CardText(question: "  dobry  dzień\n", answer: "\tguten  Tag ", hint: " Gruß\n"))
        #expect(text.question == "dobry  dzień")
        #expect(text.answer == "guten  Tag")
        #expect(text.hint == "Gruß")
    }

    @Test func requiresQuestionAndAnswer() {
        #expect(CardText(question: " \n", answer: "Haus") == nil)
        #expect(CardText(question: "dom", answer: "\t") == nil)
        #expect(CardText(question: "", answer: "") == nil)
    }

    @Test func aSideWithMediaMayHaveNoText() throws {
        let image = CardMedia(questionImage: "3f2a9c0b7d1e4a58.jpg")
        let sound = CardMedia(answerAudio: "3f2a9c0b7d1e4a59.mp3")
        #expect(try #require(CardText(question: " ", answer: "Haus", media: image)).question == "")
        #expect(try #require(CardText(question: "dom", answer: "", media: sound)).answer == "")
        // The media of the other side doesn't count, and neither side may be empty without its own.
        #expect(CardText(question: "", answer: "Haus", media: sound) == nil)
        #expect(CardText(question: "dom", answer: "", media: image) == nil)
        #expect(CardText(question: "", answer: "Haus") == nil)
    }

    @Test func hintMayBeEmpty() {
        #expect(CardText(question: "dom", answer: "Haus", hint: "  ")?.hint == "")
    }

    @Test(arguments: [
        ("Dom", " dom\n"),
        ("Straße", "STRASSE"),
        ("Ärger", "ärger"),
        ("ﬁsh", "FISH"),
        ("ΣΟΦΟΣ", "σοφος"),
        ("İstanbul", "i\u{307}stanbul"),
        ("CAF\u{C9}", "cafe\u{301}"),
    ])
    func questionsDifferingInCaseAreTheSame(_ question: String, _ other: String) {
        #expect(CardText.key(forQuestion: question) == CardText.key(forQuestion: other))
    }

    @Test(arguments: [
        ("dom", "dóm"),
        ("Ärger", "Arger"),
        ("İstanbul", "istanbul"),
        ("ISTANBUL", "ıstanbul"),
        ("dom", "do m"),
    ])
    func questionsDifferingOtherwiseAreNotTheSame(_ question: String, _ other: String) {
        #expect(CardText.key(forQuestion: question) != CardText.key(forQuestion: other))
    }
}
