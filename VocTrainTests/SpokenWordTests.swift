import SwiftUI
import Testing
import UIKit

@testable import VocTrain

/// The headword of a card at the largest text size: it wraps to its lines before the hint under it takes the room.
@MainActor
struct SpokenWordTests {
    final class Height { var value: CGFloat = 0 }

    /// "απαντάω (απάντησα)" in the question's stack (word over hint, 295 × 146 pt at the accessibility size the card follows)
    /// stood one line high, cut to "απαντάω (απάντ…" at half size, with room to spare under the badge; two lines are about 100 pt.
    @Test func aLongHeadwordWrapsToTwoLinesAtTheLargestTextSize() async throws {
        try #require(GreekSpeech.isUnderTest, "a test run must not speak")
        let word = Height()
        let stack = VStack(spacing: Spacing.gap) {
            SpokenWord(text: "απαντάω (απάντησα)", font: .largeTitle.weight(.semibold), sound: nil, media: nil)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { word.value = $0 }
            Text("verb").font(.title3).minimumScaleFactor(CardFace.smallestScale)
        }
        .frame(width: 295, height: 146, alignment: .bottom)
        .dynamicTypeSize(.accessibility3)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        window.rootViewController = UIHostingController(rootView: stack)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        window.isHidden = true
        #expect(word.value > 80, "the word is \(word.value) pt high")
    }
}
