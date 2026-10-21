import SwiftUI
import VocabCore

/// The grades of a card whose answer is shown, laid out by what they mean: Forgot is
/// the only "no"; Hard, Good and Easy are three kinds of "yes" and share one capsule,
/// Good in the middle and wider. Four equal buttons hid that, and Hard after forgetting
/// is the worst mistake for FSRS. Every part names the interval its grade gives now.
///
/// On the Mac the keys 1 to 4 choose a grade, and Return accepts `defaultGrade`.
struct GradeChoice: View {
    /// Which part to show: the iPhone in landscape puts them in one row, around the progress.
    enum Part {
        case both, forgot, recalled
    }

    var part = Part.both
    /// What each grade gives now, see `Scheduler.previewIntervals`; `nil` where grading
    /// schedules nothing, in practice.
    var intervals: [Grade: ReviewInterval]?
    /// The grade Return accepts on the Mac, marked on its button: the suggestion after a
    /// typed response, Good with flash cards.
    var defaultGrade: Grade?
    /// Lets Space accept `defaultGrade` too, as Space showed the answer.
    var acceptsSpace = false
    /// The iPhone in landscape, where the row of buttons has little height.
    var isCompact = false
    var onGrade: @MainActor (Grade) -> Void

    var body: some View {
        Group {
            switch part {
            case .both:
                VStack(spacing: 4) {
                    forgot
                        .padding(.bottom, 6)
                    Text("Recalled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    recalled
                }
            case .forgot:
                forgot
            case .recalled:
                recalled
            }
        }
        #if os(macOS)
        .background { acceptKeys }
        #endif
    }

    private var forgot: some View {
        let title = String(localized: "Forgot")
        return Button {
            onGrade(.again)
        } label: {
            VStack(spacing: 2) {
                Label(title, systemImage: "xmark")
                    .font(titleFont(emphasised: true))
                    .lineLimit(1)
                details(of: .again)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 52)
            .background(Grade.again.color, in: Capsule())
            .overlay { marker(of: .again, color: .white) }
            .contentShape(Capsule())
        }
        .buttonStyle(Pressable())
        #if os(macOS)
        .keyboardShortcut(Grade.again.shortcutKey, modifiers: [])
        #endif
        .accessibilityLabel(spoken(title, of: .again))
    }

    /// Hard, Good and Easy: one shape, so the three read as one answer.
    private var recalled: some View {
        WeightedRow(weights: [1, 1.4, 1]) {
            segment(.hard)
                .overlay(alignment: .trailing) { separator }
            segment(.good)
            segment(.easy)
                .overlay(alignment: .leading) { separator }
        }
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Recalled"))
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.recalled.opacity(0.4))
            .frame(width: 1)
    }

    /// Good is filled; Hard and Easy are tinted.
    private func segment(_ grade: Grade) -> some View {
        let isGood = grade == .good
        let textColor = isGood ? Color.white : Color.onRecalledTint
        return Button {
            onGrade(grade)
        } label: {
            VStack(spacing: 2) {
                Text(grade.title)
                    .font(titleFont(emphasised: isGood))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                details(of: grade)
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 56, maxHeight: .infinity)
            .background(isGood ? Color.recalled : Color.recalled.opacity(0.16))
            .overlay { marker(of: grade, color: textColor) }
            .contentShape(Rectangle())
        }
        .buttonStyle(Pressable())
        #if os(macOS)
        .keyboardShortcut(grade.shortcutKey, modifiers: [])
        #endif
        .accessibilityLabel(spoken(grade.title, of: grade))
    }

    private func titleFont(emphasised: Bool) -> Font {
        #if os(macOS)
        emphasised ? .body.weight(.semibold) : .body
        #else
        emphasised ? (isCompact ? Font.body : Font.title3).weight(.semibold) : .body
        #endif
    }

    /// The interval below the title, on the Mac the key too.
    @ViewBuilder
    private func details(of grade: Grade) -> some View {
        if let interval = intervals?[grade] {
            Text(Format.interval(interval))
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        #if os(macOS)
        if grade == defaultGrade {
            Text("\(grade.rawValue) or ↩")
                .font(.caption2)
        } else {
            Text(verbatim: "\(grade.rawValue)")
                .font(.caption2)
        }
        #endif
    }

    /// A ring in the part that Return accepts.
    @ViewBuilder
    private func marker(of grade: Grade, color: Color) -> some View {
        #if os(macOS)
        if grade == defaultGrade {
            Capsule()
                .strokeBorder(color, lineWidth: 2)
                .padding(3)
        }
        #endif
    }

    /// For VoiceOver: the grade and its interval, "Good, 4 days".
    private func spoken(_ title: String, of grade: Grade) -> String {
        guard let interval = intervals?[grade] else { return title }
        return "\(title), \(Format.interval(interval, spelledOut: true))"
    }

    #if os(macOS)
    /// Return, and Space if asked, accept `defaultGrade`. A button takes one shortcut.
    @ViewBuilder
    private var acceptKeys: some View {
        if let defaultGrade {
            Group {
                Button {
                    onGrade(defaultGrade)
                } label: {
                    Text(verbatim: "")
                }
                .keyboardShortcut(.defaultAction)
                if acceptsSpace {
                    Button {
                        onGrade(defaultGrade)
                    } label: {
                        Text(verbatim: "")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                }
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
    #endif
}

/// Dims a button while it is pressed; the grade buttons draw their own shape.
private struct Pressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Places its views side by side, each as wide as its share of the weights says.
private struct WeightedRow: Layout {
    var weights: [CGFloat]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        let height = zip(subviews, widths(in: width))
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max()
        return CGSize(width: width, height: height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(in: bounds.width)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width
        }
    }

    private func widths(in total: CGFloat) -> [CGFloat] {
        let sum = weights.reduce(0, +)
        return weights.map { total * $0 / sum }
    }
}
