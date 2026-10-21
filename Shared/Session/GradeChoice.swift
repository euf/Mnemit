import SwiftUI
import VocabCore

/// The grades of a card whose answer is shown, laid out by what they mean: Forgot is
/// the only "no"; Hard, Good and Easy are three kinds of "yes" and share one capsule,
/// Good in the middle and wider. Four equal buttons hid that, and Hard after forgetting
/// is the worst mistake for FSRS. The buttons carry the grade's name and nothing else:
/// when the card comes back shows only once the grade is given, see `UndoChip`.
///
/// On the Mac the keys 1 to 4 choose a grade, and Return accepts `defaultGrade`.
struct GradeChoice: View {
    /// Which part to show: the iPhone in landscape puts them in one row, around the progress.
    enum Part {
        case both, forgot, recalled
    }

    var part = Part.both
    /// The grade Return accepts on the Mac, marked on its button: the suggestion after a
    /// typed response, Good with flash cards.
    var defaultGrade: Grade?
    /// Lets Space accept `defaultGrade` too, as Space showed the answer.
    var acceptsSpace = false
    /// Lets the arrow keys grade on the Mac, the way a swipe does on the iPhone: ← Forgot,
    /// → Good, ↑ Easy, ↓ Hard.
    var acceptsArrows = false
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
        .background { extraKeys }
        #endif
    }

    private var forgot: some View {
        let title = String(localized: "Forgot")
        return Button {
            onGrade(.again)
        } label: {
            Label(title, systemImage: "xmark")
                .font(titleFont(emphasised: true))
                .lineLimit(1)
                .foregroundStyle(Grade.again.onColor)
                .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 52)
                .background(Grade.again.color, in: Capsule())
                .overlay { marker(of: .again) }
                .contentShape(Capsule())
        }
        .buttonStyle(Pressable())
        #if os(macOS)
        .keyboardShortcut(Grade.again.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(Grade.again.rawValue)"))
        #endif
    }

    /// Hard, Good and Easy: one shape, so the three read as one answer, three shades of
    /// one green.
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
            .fill(.background)
            .frame(width: 1)
    }

    private func segment(_ grade: Grade) -> some View {
        Button {
            onGrade(grade)
        } label: {
            Text(grade.title)
                .font(titleFont(emphasised: grade == .good))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(grade.onColor)
                .frame(maxWidth: .infinity, minHeight: isCompact ? 44 : 56, maxHeight: .infinity)
                .background(grade.color)
                .overlay { marker(of: grade) }
                .contentShape(Rectangle())
        }
        .buttonStyle(Pressable())
        #if os(macOS)
        .keyboardShortcut(grade.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(grade.rawValue)"))
        #endif
    }

    private func titleFont(emphasised: Bool) -> Font {
        #if os(macOS)
        emphasised ? .body.weight(.semibold) : .body
        #else
        emphasised ? (isCompact ? Font.body : Font.title3).weight(.semibold) : .body
        #endif
    }

    /// A ring in the part that Return accepts.
    @ViewBuilder
    private func marker(of grade: Grade) -> some View {
        #if os(macOS)
        if grade == defaultGrade {
            Capsule()
                .strokeBorder(grade.onColor, lineWidth: 2)
                .padding(3)
        }
        #endif
    }

    #if os(macOS)
    /// Return, Space and the arrows, each a button of its own: a button takes one shortcut.
    @ViewBuilder
    private var extraKeys: some View {
        Group {
            if let defaultGrade {
                key(.return, grade: defaultGrade)
                if acceptsSpace {
                    key(.space, grade: defaultGrade)
                }
            }
            if acceptsArrows {
                key(.leftArrow, grade: .again)
                key(.rightArrow, grade: .good)
                key(.upArrow, grade: .easy)
                key(.downArrow, grade: .hard)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func key(_ key: KeyEquivalent, grade: Grade) -> some View {
        Button {
            onGrade(grade)
        } label: {
            Text(verbatim: "")
        }
        .keyboardShortcut(key, modifiers: [])
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
