import Foundation
import Testing
import VocabCore

@testable import VocTrain

/// The grade colours keep their contrast in light and dark mode, by arithmetic on the hex values of
/// `Grade.swatch`: 4.5:1 for the label on a button, and the card's text on the tint it takes while it
/// is swiped, which `CardFlight` lays at 70 % over the card face. The card face and the screen
/// behind it are the values of `Color.cardSurface` and `Color.studyBackdrop`.
struct GradeContrastTests {
    private static func channels(_ hex: UInt32) -> [Double] {
        [Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF)]
    }

    private static func luminance(_ rgb: [Double]) -> Double {
        let linear = rgb.map { channel -> Double in
            let value = channel / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private static func ratio(_ first: [Double], _ second: [Double]) -> Double {
        let (a, b) = (luminance(first), luminance(second))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func over(_ top: [Double], _ bottom: [Double], _ opacity: Double) -> [Double] {
        zip(top, bottom).map { $0 * opacity + $1 * (1 - opacity) }
    }

    /// The card faces: white in light mode, the iPhone's raised grey and the Mac's in dark mode.
    private static let faces: [(dark: Bool, hex: UInt32)] = [(false, 0xFFFFFF), (true, 0x1C1C1E), (true, 0x2C2C2E)]

    @Test(arguments: Grade.allCases)
    func theLabelOfAGradeButtonHoldsFourAndAHalfToOne(grade: Grade) {
        let swatch = grade.swatch
        for (name, fill, label) in [("light", swatch.fill.light, swatch.label.light), ("dark", swatch.fill.dark, swatch.label.dark)] {
            let value = Self.ratio(Self.channels(fill), Self.channels(label))
            #expect(value >= 4.5, "\(grade) \(name): \(value)")
        }
    }

    @Test(arguments: Grade.allCases)
    func theTextOfASwipedCardHoldsItsContrastOnTheTint(grade: Grade) {
        let swatch = grade.swatch
        for face in Self.faces {
            let tint = face.dark ? swatch.tint.dark : swatch.tint.light
            let ground = Self.over(Self.channels(tint), Self.channels(face.hex), 0.7)
            let text = face.dark ? [255.0, 255, 255] : [0.0, 0, 0]
            let primary = Self.ratio(ground, text)
            let secondary = Self.ratio(ground, Self.over(text, ground, 0.75))
            #expect(primary >= (face.dark ? 7.1 : 5.5), "\(grade) \(String(face.hex, radix: 16)): primary \(primary)")
            #expect(secondary >= (face.dark ? 4.7 : 4.3), "\(grade) \(String(face.hex, radix: 16)): secondary \(secondary)")
        }
    }

    /// OKLCH chroma of a hex colour (Björn Ottosson's Oklab).
    private static func chroma(_ hex: UInt32) -> Double {
        let linear = channels(hex).map { value -> Double in
            let channel = value / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let l = cbrt(0.4122214708 * linear[0] + 0.5363325363 * linear[1] + 0.0514459929 * linear[2])
        let m = cbrt(0.2119034982 * linear[0] + 0.6806995451 * linear[1] + 0.1073969566 * linear[2])
        let s = cbrt(0.0883024619 * linear[0] + 0.2817188376 * linear[1] + 0.6299787005 * linear[2])
        let a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        return (a * a + b * b).squareRoot()
    }

    @Test func chromaRisesFromHardToEasyAndHardIsStillGreen() {
        for dark in [false, true] {
            func fill(_ grade: Grade) -> UInt32 { dark ? grade.swatch.fill.dark : grade.swatch.fill.light }
            #expect(Self.chroma(fill(.hard)) < Self.chroma(fill(.good)))
            #expect(Self.chroma(fill(.good)) < Self.chroma(fill(.easy)))
            let rgb = Self.channels(fill(.hard))
            #expect(rgb[1] - rgb[0] >= 30, "green leads red clearly: not a grey")
        }
    }

    @Test(arguments: [Grade.hard, .good, .easy])
    func theRingOfAGreenShowsOnTheScreenBehindTheButtons(grade: Grade) {
        let light = Self.ratio(Self.channels(grade.swatch.ring.light), Self.channels(0xF2F2F7))
        let dark = Self.ratio(Self.channels(grade.swatch.ring.dark), Self.channels(0x1C1C1E))
        #expect(light >= 3, "\(grade) light: \(light)")
        #expect(dark >= 3, "\(grade) dark: \(dark)")
    }
}
