import Testing

@testable import VocTrain

/// The endings of a Greek headword stay with it on a line.
@Suite(.timeLimit(.minutes(1)))
struct CardFaceEndingsTests {
    @Test func theEndingsOfAWordAreTiedWithNonBreakingSpaces() {
        #expect("υπεύθυνος, -η, -ο".keepingEndingsTogether == "υπεύθυνος,\u{00A0}-η,\u{00A0}-ο")
        #expect("ο κλέφτης, -ου".keepingEndingsTogether == "ο κλέφτης,\u{00A0}-ου")
    }

    @Test func otherTextKeepsItsSpaces() {
        for text in ["to answer, to reply", "απαντάω (απάντησα)", "καλός, καλή, καλό", "5 - 3", "a, - b"] {
            #expect(text.keepingEndingsTogether == text)
        }
    }
}
