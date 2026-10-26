import SwiftUI
import Testing
import UIKit

@testable import VocTrain
@testable import VocabCore

/// The words in memory and the gain of the day on Today: "28 words in memory · +15 today" is one line where
/// the row has its width, 310 pt on a 375 pt screen, and one wrapping text where it has not.
@MainActor
struct MemoryLineTests {
    /// The height `view` takes at `width` and the type size.
    func height(_ view: some View, width: CGFloat, type: DynamicTypeSize) -> CGFloat {
        let controller = UIHostingController(rootView: view.font(.subheadline).dynamicTypeSize(type))
        return controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    @Test func theGainStaysOnTheLineOfTheWords() {
        let memory = MemoryEstimate(words: 28.4, wordsAtDayStart: 13.2)
        let oneLine = height(Text(verbatim: "≈"), width: 310, type: .large)
        #expect(abs(height(MemoryLine(memory: memory), width: 310, type: .large) - oneLine) < 1)
        // The words alone take a line, too.
        #expect(abs(height(MemoryLine(memory: MemoryEstimate(words: 28.4, wordsAtDayStart: 28.4)), width: 310, type: .large) - oneLine) < 1)
    }

    /// At a large type size the line is too long for the row: it wraps as one text.
    @Test func atALargeTypeSizeTheLineWraps() {
        let memory = MemoryEstimate(words: 28.4, wordsAtDayStart: 13.2)
        let oneLine = height(Text(verbatim: "≈"), width: 310, type: .accessibility3)
        #expect(height(MemoryLine(memory: memory), width: 310, type: .accessibility3) > oneLine + 1)
    }
}
