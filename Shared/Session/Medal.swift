import SwiftUI
import VocabCore

/// The disc of a medal: earned, the emoji face at 60 % on a soft gradient of the accent, a thin ring and a
/// shadow of it; the next one, an empty disc with a dashed outline and the line's SF Symbol, all in
/// `Color.inactiveMark`, its emoji a surprise. A line that repeats shows how often as a badge on the top-trailing edge.
struct MedalDisc: View {
    var kind: AchievementKind
    var isEarned = true
    /// How often it was earned, for a line that repeats; a badge from the second time.
    var count = 1
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if isEarned {
                Circle().fill(
                    LinearGradient(
                        colors: [Color.appAccentOnRaised.opacity(0.30), Color.appAccentOnRaised.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(Color.appAccentOnRaised, lineWidth: 1)
                Text(verbatim: kind.face)
                    .font(.system(size: size * 0.6))
            } else {
                Circle().strokeBorder(Color.inactiveMark, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Color.inactiveMark)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: isEarned ? Color.appAccentOnRaised.opacity(0.3) : .clear, radius: 4, y: 2)
        .overlay(alignment: .topTrailing) {
            if isEarned, count > 1 {
                Text(count, format: .number)
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.hairline)
                    .frame(minWidth: Spacing.margin)
                    .background(Capsule().fill(Color.appAccentOnRaised))
                    .offset(x: Spacing.hairline, y: -Spacing.hairline)
            }
        }
    }
}

/// A medal of the achievements (`references/learning-flow.md`, "Milestones, achievements and the Progress
/// screen"): the disc, the title under it, and the date it was earned, or for a grey medal how far there is to go.
/// The grey one is at full opacity; its contrast comes from its colours.
///
/// On the Progress screen and the month's screen at 44 pt, on the rests and in the list of Today at 36.
struct Medal: View {
    var kind: AchievementKind
    var isEarned = true
    /// The day it was earned, under the title; `nil` on the rests, where it is today.
    var date: Date?
    /// How often it was earned, for a line that repeats: the badge on the disc.
    var count = 1
    /// How far the next tier is, "12 of 14 days", under the title of a grey medal.
    var hint: String?
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: Spacing.hairline) {
            MedalDisc(kind: kind, isEarned: isEarned, count: count, size: size)
            Text(verbatim: kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEarned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let caption {
                Text(verbatim: caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(width: size * 2.2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))
    }

    /// The date it was earned, or how far the next tier is.
    private var caption: String? {
        isEarned ? date?.formatted(.dateTime.day().month(.abbreviated)) : hint
    }

    /// The title, what it took, how often, and the date, or "Not yet, 12 of 14 days".
    private var spoken: String {
        let last: String? =
            if isEarned {
                date?.formatted(date: .long, time: .omitted)
            } else {
                hint.map { String(localized: "Not yet, \($0)") } ?? String(localized: "Not yet")
            }
        let often = isEarned && count > 1 ? String(localized: "Earned \(count) times") : nil
        return [kind.title, kind.detail, often, last].compactMap { $0 }.joined(separator: ", ")
    }
}
