import SwiftUI
import VocabCore

/// A medal of the achievements (`references/learning-flow.md`, "Milestones, achievements and the Progress
/// screen"): earned, the emoji face on a soft tint of the accent with a thin ring of it; the next one, the line's
/// SF Symbol in grey, its emoji a surprise. The title under it, and the date it was earned, or for a grey medal
/// how far there is to go.
///
/// On the Progress screen and the month's screen at 44 pt, on the rests at 36.
struct Medal: View {
    var kind: AchievementKind
    var isEarned = true
    /// The day it was earned, under the title; `nil` on the rests, where it is today.
    var date: Date?
    /// How often it was earned, for a line that repeats: "×3" after the title.
    var count = 1
    /// How far the next tier is, "12 of 14 days", under the title of a grey medal.
    var hint: String?
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: Spacing.hairline) {
            disc
            Text(verbatim: title)
                .font(.caption)
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

    private var title: String {
        count > 1 ? "\(kind.title) ×\(count)" : kind.title
    }

    private var disc: some View {
        ZStack {
            if isEarned {
                Circle().fill(Color.appAccentOnRaised.opacity(0.15))
                Circle().strokeBorder(Color.appAccentOnRaised, lineWidth: 1)
                Text(verbatim: kind.face)
                    .font(.system(size: size * 0.6))
            } else {
                Circle().fill(Color.secondary.opacity(0.15))
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    /// The title, what it took, and the date, or "Not yet, 12 of 14 days".
    private var spoken: String {
        let last: String? =
            if isEarned {
                date?.formatted(date: .long, time: .omitted)
            } else {
                hint.map { String(localized: "Not yet, \($0)") } ?? String(localized: "Not yet")
            }
        return [title, kind.detail, last].compactMap { $0 }.joined(separator: ", ")
    }
}
