import SwiftUI
import VocabCore

/// The grades of a card whose answer is shown, laid out by what they mean: Forgot is
/// the only "no"; Hard, Good and Easy are three kinds of "yes" and share a row under their
/// own caption, Good in the middle and wider. Four equal buttons hid that, and Hard after
/// forgetting is the worst mistake for FSRS. The buttons carry the grade's name and nothing
/// else: when the card comes back shows only once the grade is given, see `UndoChip`.
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
    /// The grade a swipe is about to give, or a key has just given: its button stands out
    /// and the others step back (`CardFlight.highlighted`).
    var highlighted: Grade?
    var onGrade: @MainActor (Grade) -> Void

    /// Controls of the platform's size: 52 pt on the iPhone, 44 in landscape, 38 on the Mac.
    private var height: CGFloat {
        #if os(macOS)
        38
        #else
        isCompact ? 44 : 52
        #endif
    }

    private var shape: RoundedRectangle {
        #if os(macOS)
        RoundedRectangle(cornerRadius: 10, style: .continuous)
        #else
        RoundedRectangle(cornerRadius: 14, style: .continuous)
        #endif
    }

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
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(Grade.again.onColor)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Grade.again.color, in: shape)
                .overlay { marker(of: .again) }
                .contentShape(shape)
        }
        .buttonStyle(Pressable())
        .modifier(Emphasis(grade: .again, highlighted: highlighted))
        #if os(macOS)
        .keyboardShortcut(Grade.again.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(Grade.again.rawValue)"))
        #endif
    }

    /// Hard, Good and Easy: three buttons of one height in a row, three shades of one
    /// green, Good wider.
    private var recalled: some View {
        WeightedRow(weights: [1, 1.25, 1], spacing: 8) {
            segment(.hard)
            segment(.good)
            segment(.easy)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Recalled"))
    }

    private func segment(_ grade: Grade) -> some View {
        Button {
            onGrade(grade)
        } label: {
            Text(grade.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(grade.onColor)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: .infinity)
                .background(grade.color, in: shape)
                .overlay { marker(of: grade) }
                .contentShape(shape)
        }
        .buttonStyle(Pressable())
        .modifier(Emphasis(grade: grade, highlighted: highlighted))
        #if os(macOS)
        .keyboardShortcut(grade.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(grade.rawValue)"))
        #endif
    }

    /// A ring in the button that Return accepts.
    @ViewBuilder
    private func marker(of grade: Grade) -> some View {
        #if os(macOS)
        if grade == defaultGrade {
            shape.inset(by: 3)
                .strokeBorder(grade.onColor, lineWidth: 2)
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

/// Lights up the button of the grade a swipe is about to give or a key has just given, and
/// steps the others back. All buttons stay as they are while no grade is highlighted.
private struct Emphasis: ViewModifier {
    var grade: Grade
    var highlighted: Grade?

    func body(content: Content) -> some View {
        content
            .opacity(highlighted == nil || highlighted == grade ? 1 : 0.35)
            .scaleEffect(highlighted == grade ? 1.03 : 1)
            .animation(.easeOut(duration: 0.12), value: highlighted)
    }
}

/// Places its views side by side with `spacing` between them, each as wide as its share of
/// the weights says. The row is as high as its highest view wants to be, never higher, and
/// its views fill that height.
private struct WeightedRow: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        // Without a height proposal, as views that fill their height would take all of it.
        let height = zip(subviews, widths(in: width))
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
            .max()
        return CGSize(width: width, height: height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(in: bounds.width)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func widths(in total: CGFloat) -> [CGFloat] {
        let sum = weights.reduce(0, +)
        let free = max(0, total - spacing * CGFloat(weights.count - 1))
        return weights.map { free * $0 / sum }
    }
}
