import SwiftUI
import VocabCore

/// The grades of a card whose answer is shown, laid out by what they mean: Forgot is
/// the only "no" and has a row of its own; Hard, Good and Easy are three kinds of "yes" and
/// share the row under it, Good in the middle and wider. Four equal buttons hid that, and Hard after
/// forgetting is the worst mistake for FSRS. The buttons carry the grade's name and nothing
/// else: when the card comes back shows only once the grade is given, see `UndoChip`.
///
/// On the Mac the keys 1 to 4 choose a grade, Return accepts `defaultGrade`, and each button carries
/// the arrow key that gives its grade, the direction of the iPhone's swipe (`Grade.arrowKey`).
struct GradeChoice: View {
    /// Which part to show: the iPhone in landscape puts them in one row, around the progress.
    enum Part {
        case both, forgot, recalled
    }

    var part = Part.both
    /// The grade Return accepts on the Mac, marked on its button.
    var defaultGrade: Grade?
    /// Lets Space accept `defaultGrade` too, as Space showed the answer.
    var acceptsSpace = false
    /// Lets the arrow keys grade on the Mac, the way a swipe does on the iPhone: ← Forgot,
    /// ↓ Hard, → Good, ↑ Easy.
    var acceptsArrows = false
    /// The iPhone in landscape, where the row of buttons has little height.
    var isCompact = false
    /// The card is on its first showing (`Card.isNew`): two wide buttons, Don't know (Again) and Know (Good), take the place of
    /// the four. A swipe still gives every grade; from the second showing on the four buttons are back.
    var isNew = false
    /// The grade a swipe is about to give, or a key has just given: its button stands out
    /// and the others step back (`CardFlight.highlighted`).
    var highlighted: Grade?
    var onGrade: @MainActor (Grade) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 50 pt at the default text size, as high as Show Answer, which takes the place of the
    /// buttons before the answer shows.
    @ScaledMetric(relativeTo: .body) private var scaledHeight: CGFloat = 50

    /// Controls of the platform's size: 50 pt on the iPhone, 44 in landscape, 38 on the Mac.
    private var height: CGFloat {
        #if os(macOS)
        38
        #else
        isCompact ? 44 : scaledHeight
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
            case .both where isNew && dynamicTypeSize.isAccessibilitySize:
                // The titles no longer fit side by side, as with the three grades: one above the other, in the same room.
                VStack(spacing: Spacing.gap) {
                    forgot(minHeight: height)
                    know(minHeight: height)
                }
            case .both where isNew:
                HStack(spacing: Spacing.gap) {
                    forgot(minHeight: 2 * height + Spacing.gap)
                    know(minHeight: 2 * height + Spacing.gap)
                }
            case .both:
                VStack(spacing: 0) {
                    forgot(minHeight: height)
                        .padding(.bottom, Spacing.gap)
                    recalled
                }
            case .forgot:
                forgot(minHeight: height)
            case .recalled where isNew:
                know(minHeight: height)
            case .recalled:
                recalled
            }
        }
        #if os(macOS)
        .background { extraKeys }
        #endif
    }

    private func forgot(minHeight: CGFloat) -> some View {
        let title = Grade.again.buttonTitle(isNew: isNew)
        return Button {
            onGrade(.again)
        } label: {
            labelled(.again) { Label(title, systemImage: "xmark") }
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(Grade.again.onColor)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Grade.again.color, in: shape)
                .overlay { marker(of: .again) }
                .overlay { outline(of: .again) }
                .contentShape(shape)
        }
        .buttonStyle(Pressable())
        .modifier(Emphasis(grade: .again, highlighted: highlighted, scale: 1.06))
        #if os(macOS)
        .keyboardShortcut(Grade.again.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(Grade.again.rawValue)"))
        #endif
    }

    /// Know, the first showing's one "yes": Good, in the green of yes, as wide as its share of the row.
    private func know(minHeight: CGFloat) -> some View {
        Button {
            onGrade(.good)
        } label: {
            labelled(.good) { Label(Grade.good.buttonTitle(isNew: true), systemImage: "checkmark") }
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(Grade.good.onColor)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Grade.good.color, in: shape)
                .overlay { marker(of: .good) }
                .overlay { outline(of: .good) }
                .contentShape(shape)
        }
        .buttonStyle(Pressable())
        .modifier(Emphasis(grade: .good, highlighted: highlighted, scale: 1.06))
        #if os(macOS)
        .keyboardShortcut(Grade.good.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(Grade.good.rawValue)"))
        #endif
    }

    /// Hard, Good and Easy: three buttons of one height in a row, three strengths of one
    /// green, Good wider. At accessibility sizes the titles no longer fit side by side and the
    /// buttons stack.
    @ViewBuilder
    private var recalled: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.gap) {
                    segment(.hard)
                    segment(.good)
                    segment(.easy)
                }
            } else {
                WeightedRow(weights: [1, 1.25, 1], spacing: Spacing.gap) {
                    segment(.hard)
                    segment(.good)
                    segment(.easy)
                }
            }
        }
    }

    private func segment(_ grade: Grade) -> some View {
        Button {
            onGrade(grade)
        } label: {
            labelled(grade) { Text(grade.title) }
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(grade.onColor)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: .infinity)
                .background(grade.color, in: shape)
                .overlay { marker(of: grade) }
                .overlay { outline(of: grade) }
                .contentShape(shape)
        }
        .buttonStyle(Pressable())
        .modifier(Emphasis(grade: grade, highlighted: highlighted))
        #if os(macOS)
        .keyboardShortcut(grade.shortcutKey, modifiers: [])
        .help(Text(verbatim: "\(grade.rawValue)"))
        #endif
    }

    /// The button's label; on the Mac, with the grade's arrow key as a keycap after it.
    @ViewBuilder
    private func labelled(_ grade: Grade, @ViewBuilder _ label: () -> some View) -> some View {
        #if os(macOS)
        HStack(spacing: 8) {
            label()
            KeyCap(Text(verbatim: grade.arrow))
        }
        #else
        label()
        #endif
    }

    /// The ring round the button of the grade a swipe is about to give, in the grade's own
    /// colour and clear of the fill so it shows against the screen.
    private func outline(of grade: Grade) -> some View {
        shape.inset(by: -3.5)
            .stroke(grade.ring, lineWidth: 2)
            .opacity(highlighted == grade ? 1 : 0)
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
                ForEach(Grade.allCases, id: \.self) { key($0.arrowKey, grade: $0) }
            }
            // The keys of the two grades a first showing has no button for.
            if isNew {
                key(Grade.hard.shortcutKey, grade: .hard)
                key(Grade.easy.shortcutKey, grade: .easy)
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
/// steps the others back: the chosen one grows by 8 % in full colour with a ring of its own
/// (`GradeChoice.outline(of:)`), the others fade to 15 % and lose their colour, so the choice
/// reads at a glance from the corner of the eye. All buttons stay as they are while no grade is
/// highlighted.
private struct Emphasis: ViewModifier {
    var grade: Grade
    var highlighted: Grade?
    /// How much the chosen button grows; the full-width Forgot grows less, so with its ring it
    /// stays inside the 16 pt margins of the screen.
    var scale = 1.08

    func body(content: Content) -> some View {
        let isOther = highlighted != nil && highlighted != grade
        content
            .saturation(isOther ? 0 : 1)
            .opacity(isOther ? 0.15 : 1)
            .scaleEffect(highlighted == grade ? scale : 1)
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
