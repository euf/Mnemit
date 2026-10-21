import SwiftUI
import Testing
import UIKit

@testable import VocTrain

/// Measures, by pixels, where the speaker glyph stands beside a word of the card: the word is in
/// capitals without accents or tails (`ΑΠΑΝΤΑΩ`), so the ink of its first line runs from the top
/// of the capitals to the baseline, and the glyph, in the lighter secondary grey, is told from
/// the word by its place right of the last dark column. Offsets are in points, positive downwards.
@Suite(.serialized)
@MainActor
struct SpeakerAlignmentTests {
    struct Measure: CustomStringConvertible {
        /// The glyph's centre minus the centre of the capitals of the first line.
        var centre: Double
        /// The glyph's bottom minus the baseline of the first line.
        var bottom: Double
        var glyphHeight: Double
        var capHeight: Double

        var description: String {
            String(format: "centre %+.2f pt, bottom-to-baseline %+.2f pt, glyph %.1f pt high, capitals %.1f pt high", centre, bottom, glyphHeight, capHeight)
        }
    }

    private var directory: URL {
        let path = ProcessInfo.processInfo.environment["STUDY_SHOTS_DIR"]
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("study-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The row on white, at the text size `size`, hosted in a window.
    private func measure<Row: View>(_ row: Row, size: DynamicTypeSize = .large, name: String) async throws -> Measure {
        try #require(GreekSpeech.isUnderTest)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let bounds = CGRect(x: 0, y: 0, width: 375, height: 360)
        window.frame = bounds
        window.overrideUserInterfaceStyle = .light
        window.windowLevel = .alert + 1
        let root = VStack {
            row
                .multilineTextAlignment(.center)
                .frame(width: 300)
                .padding(.top, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .dynamicTypeSize(size)
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(300))
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            window.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        if let data = image.pngData() {
            try? data.write(to: directory.appendingPathComponent("align-\(name).png"))
        }
        return try measured(PixelBitmap(image))
    }

    private func measured(_ bitmap: PixelBitmap) throws -> Measure {
        let (width, height) = (bitmap.width, bitmap.height)
        // The word: black. Its last dark column ends it.
        var lastDark = -1
        var darkRows = Set<Int>()
        for x in 0..<width {
            for y in 0..<height where bitmap.luminance(x, y) < 0.3 {
                lastDark = max(lastDark, x)
                darkRows.insert(y)
            }
        }
        try #require(lastDark > 0, "no word in the picture")
        // The first line: the first run of rows with word ink, in the columns of the word.
        let rows = darkRows.sorted()
        var lineEnd = rows[0]
        for row in rows.dropFirst() {
            guard row == lineEnd + 1 else { break }
            lineEnd = row
        }
        let capTop = rows[0]
        let baseline = lineEnd + 1
        // The glyph: lighter ink right of the word.
        var glyphTop = Int.max
        var glyphBottom = Int.min
        for x in (lastDark + 3)..<width {
            for y in 0..<height where bitmap.luminance(x, y) < 0.85 {
                glyphTop = min(glyphTop, y)
                glyphBottom = max(glyphBottom, y + 1)
            }
        }
        try #require(glyphBottom > glyphTop, "no speaker in the picture")
        let scale = Double(bitmap.scale)
        let glyphCentre = Double(glyphTop + glyphBottom) / 2 / scale
        let capCentre = Double(capTop + baseline) / 2 / scale
        return Measure(
            centre: glyphCentre - capCentre,
            bottom: Double(glyphBottom - baseline) / scale,
            glyphHeight: Double(glyphBottom - glyphTop) / scale,
            capHeight: Double(baseline - capTop) / scale)
    }

    private static let font = Font.largeTitle.weight(.semibold)
    private static let oneLine = "ΑΠΑΝΤΑΩ"
    private static let twoLines = "ΑΠΑΝΤΑΩ ΑΠΑΝΤΗΣΑ"

    /// The row as it was: centred, the speaker at its own size.
    private func before(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text).font(Self.font).minimumScaleFactor(0.6)
            SpeakButton(text: text)
        }
    }

    private func after(_ text: String) -> some View {
        SpokenWord(text: text, font: Self.font)
    }

    @Test
    func speakerStandsOnTheFirstLine() async throws {
        var report = ""
        for (label, size) in [("default", DynamicTypeSize.large), ("xxxLarge", .xxxLarge), ("AX1", .accessibility1)] {
            for (lines, text) in [("one line", Self.oneLine), ("two lines", Self.twoLines)] {
                let old = try await measure(before(text), size: size, name: "before-\(label)-\(lines)".replacingOccurrences(of: " ", with: "-"))
                let new = try await measure(after(text), size: size, name: "after-\(label)-\(lines)".replacingOccurrences(of: " ", with: "-"))
                report += "\(label), \(lines)\n  before: \(old)\n  after:  \(new)\n"
                // Within a point of the middle of the capitals and of the baseline.
                #expect(abs(new.centre) <= 1.0, "\(label), \(lines): \(new)")
                #expect(abs(new.bottom) <= 1.0, "\(label), \(lines): \(new)")
            }
        }
        try? report.write(to: directory.appendingPathComponent("align-report.txt"), atomically: true, encoding: .utf8)
        print(report)
    }

    /// What the card's gestures ask: is this point on a speaker that can be touched.
    @Test
    func aTouchOnASpeakerIsTheSpeakers() {
        let places = SpeakerPlaces()
        let (question, answer) = (UUID(), UUID())
        places.place(CGRect(x: 100, y: 50, width: 28, height: 28), of: question)
        places.place(CGRect(x: 100, y: 200, width: 28, height: 28), of: answer)
        #expect(places.contains(CGPoint(x: 110, y: 60)))
        #expect(places.contains(CGPoint(x: 110, y: 210)))
        #expect(!places.contains(CGPoint(x: 90, y: 60)))
        // The answer is hidden again: its speaker is nothing to leave a touch to.
        places.place(nil, of: answer)
        #expect(!places.contains(CGPoint(x: 110, y: 210)))
        #expect(places.frames.count == 1)
    }

    /// The speakers of a card tell the card where they are, which is what its gestures leave to
    /// them: the question's always, the answer's only once it shows.
    @Test(arguments: [false, true])
    func speakersReportWhereTheyAre(isRevealed: Bool) async throws {
        try #require(GreekSpeech.isUnderTest)
        let places = SpeakerPlaces()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        window.windowLevel = .alert + 1
        let face = CardFace(question: "ο Άγγλος", hint: "", answer: "англичанин · Englishman and Ο Άγγλος", isRevealed: isRevealed)
            .frame(width: 343, height: 480)
            .environment(\.speakerPlaces, places)
            .coordinateSpace(name: SpeakerPlaces.space)
        window.rootViewController = UIHostingController(rootView: face)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(400))
        window.isHidden = true
        // The answer's head has Greek in it ("Ο Άγγλος"), so it has a speaker too.
        #expect(places.frames.count == (isRevealed ? 2 : 1))
        for frame in places.frames {
            #expect(frame.width >= 28 && frame.height >= 28)
            #expect(CGRect(x: 0, y: 0, width: 343, height: 480).contains(frame), "\(frame) is not on the card")
        }
    }
}
