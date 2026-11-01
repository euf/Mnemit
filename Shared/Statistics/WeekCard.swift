import CoreTransferable
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import VocabCore

/// The card a learner shares from Progress (`references/product-model.md`, "The bragging loop"): the words right in the last
/// 7 days as the large value, the dates they span, then the day streak, the words learned and the seconds an answer, and
/// "Best week" when this week beats every earlier one. Drawn in light on its own ground, so the image is the same on
/// both devices and in any chat it lands in.
struct WeekCard: View {
    var right: WordsRight
    var streak: Int
    var learned: Int
    var span: String

    init(progress: DailyProgress, calendar: StudyCalendar) {
        right = progress.wordsRight
        streak = progress.streak.days
        learned = progress.learned.words
        let today = progress.records.last?.day ?? calendar.dayNumber(for: Date())
        let first = calendar.start(ofDay: today - WordsRight.days + 1)
        // The study day ends at 04:00 of the next date: its noon names it.
        span = (first..<calendar.start(ofDay: today).addingTimeInterval(12 * 3600)).formatted(.interval.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.gap) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "Mnemit")
                    .font(.headline)
                Spacer()
                Text(verbatim: span)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(right.words, format: .number)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text("Words right in 7 days")
                    .font(.title3.weight(.semibold))
            }
            if right.isBestWeek {
                Label("Best week", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            HStack(alignment: .top, spacing: Spacing.margin) {
                figure(Text("Day streak"), Text(streak, format: .number), tint: streak > 0 ? .streak : .secondary)
                figure(Text("Words learned"), Text(learned, format: .number))
                if let seconds = right.secondsPerAnswer {
                    figure(Text("Per answer"), Text(verbatim: Format.seconds(seconds)))
                }
            }
        }
        .padding(28)
        .frame(width: 440, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    /// A label over a value, as `Figure` draws them, the label on one line, so the three values stand on one baseline in
    /// every language.
    private func figure(_ label: Text, _ value: Text, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            label
                .font(FigureSize.regular.labelFont)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            value
                .font(FigureSize.regular.valueFont)
                .foregroundStyle(tint)
        }
    }
}

/// The week's card as a PNG, drawn when it is shared.
struct WeekCardImage: Transferable {
    var card: WeekCard

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            try await MainActor.run { try image.png() }
        }
    }

    @MainActor
    func png() throws -> Data {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        let data = NSMutableData()
        guard let image = renderer.cgImage,
            let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }
}
