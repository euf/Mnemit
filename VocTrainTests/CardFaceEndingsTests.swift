import Testing

@testable import VocTrain

/// The endings of a Greek headword stay with it on a line, and a gloss wraps as two halves.
@Suite(.timeLimit(.minutes(1)))
struct CardFaceEndingsTests {
    @Test func theEndingsOfAWordAreTiedWithNonBreakingSpaces() {
        #expect("υπεύθυνος, -η, -ο".keepingEndingsTogether == "υπεύθυνος,\u{00A0}-η,\u{00A0}-ο")
        #expect("ο κλέφτης, -ου".keepingEndingsTogether == "ο κλέφτης,\u{00A0}-ου")
    }

    @Test func aGlossIsItsTwoHalves() throws {
        let halves = try #require("после того как; раз, поскольку · after; since".glossHalves)
        #expect(halves.0 == "после того как; раз, поскольку")
        #expect(halves.1 == "after; since")
        let word = try #require("отвечать · to answer".glossHalves)
        #expect(word.0 == "отвечать" && word.1 == "to answer")
    }

    @Test func textWithoutTheSeparatorBetweenTwoHalvesIsNoGloss() {
        for text in ["to answer", "απαντάω (απάντησα)", "a·b", " · x", "x · ", "·", "", "A · "] {
            #expect(text.glossHalves == nil)
        }
    }

    @Test func otherTextKeepsItsSpaces() {
        for text in ["to answer, to reply", "απαντάω (απάντησα)", "καλός, καλή, καλό", "5 - 3", "a, - b"] {
            #expect(text.keepingEndingsTogether == text)
        }
    }
}
