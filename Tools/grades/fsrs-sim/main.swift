// Year simulation with the app's own FSRS-6 formulas (Packages/VocabCore/.../FSRS.swift compiled unmodified) and the
// Scheduler's step rules: 2 steps, Again resets, Hard keeps, Good +1, Easy -> review at once; interval = round(S / factor * (0.9^(1/decay) - 1)), >= 1, no fuzz.
// Build: see run.sh. A card is reviewed on its due day; recall happens with probability p per attempt (or R of the model with --model).
import Foundation

enum InitialStability { static let maximum = 100.0 }
public enum Grade: Int {
    case again = 1
    case hard, good, easy
    public var isRecall: Bool { self != .again }
}

struct Rng {
    var s: UInt64
    mutating func next() -> Double {
        s ^= s << 13
        s ^= s >> 7
        s ^= s << 17
        return Double(s >> 11) / Double(1 << 53)
    }
}

let fsrs = FSRS()
let target = 0.9
func interval(_ s: Double) -> Int { max(1, Int(fsrs.interval(stability: s, targetRecall: target).rounded())) }

enum Pol { case good, easy, hard, easyFirst, hardFirst }  // grade on a recalled attempt
// .hard presses Hard only on review-phase recalls: Hard keeps a learning step, so always pressing it would never leave learning.
func gradeFor(_ p: Pol, first: Bool, review: Bool) -> Grade {
    switch p {
    case .good: return .good
    case .easy: return .easy
    case .hard: return review ? .hard : .good
    case .easyFirst: return first ? .easy : .good
    case .hardFirst: return first ? .hard : .good
    }
}

struct Run { var showings = 0, reviewDays = 0, lapses = 0, days: [Int] = [], endS = 0.0, recalled = 0, attemptsAtReview = 0 }

/// p < 0: recall probability is the model's retrievability R at the review (a card that behaves as FSRS predicts).
func year(_ pol: Pol, p: Double, rng: inout Rng, horizon: Int = 365) -> Run {
    var r = Run()
    var mem: FSRS.Memory? = nil
    var phaseReview = false
    var steps = 0
    var day = 0
    var last = 0
    var first = true
    var lastReviewDay = -1
    while day < horizon && r.showings < 5000 {
        // one showing on `day`
        let elapsed = mem == nil ? 0 : day - last
        let pr: Double = p >= 0 ? p : (mem == nil ? 0.5 : fsrs.retrievability(elapsedDays: Double(elapsed), stability: mem!.stability))
        let rec = rng.next() < pr
        let g: Grade = rec ? gradeFor(pol, first: first, review: phaseReview) : .again
        let wasReview = phaseReview
        mem = fsrs.review(mem, elapsedDays: elapsed, grade: g)
        r.showings += 1
        if lastReviewDay != day {
            r.reviewDays += 1
            lastReviewDay = day
            if r.days.count < 14 { r.days.append(day) }
        }
        if wasReview {
            r.attemptsAtReview += 1
            if rec { r.recalled += 1 }
        }
        if wasReview && g == .again {
            phaseReview = false
            steps = 0
            r.lapses += 1
        } else if !phaseReview {
            switch g {
            case .again: steps = 0
            case .hard: break
            case .good: steps += 1
            case .easy: steps = 2
            }
            if steps >= 2 {
                phaseReview = true
                steps = 0
            }
        }
        last = day
        first = false
        if phaseReview { day += interval(mem!.stability) }  // else same-day showing again
    }
    r.endS = mem!.stability
    return r
}

func report(_ title: String, _ pols: [(String, Pol)], p: Double, n: Int) {
    print("\n#### \(title)")
    print("| policy | showings / 365 d | days with a review | lapses | first review days | S at end (d) |\n|---|---|---|---|---|---|")
    for (name, pol) in pols {
        var rng = Rng(s: 0x9E37_79B9_7F4A_7C15)
        var sh = 0.0
        var rd = 0.0
        var lp = 0.0
        var st = 0.0
        var firstDays: [Int] = []
        let runs = p == 1.0 ? 1 : n
        for i in 0..<runs {
            let r = year(pol, p: p, rng: &rng)
            sh += Double(r.showings)
            rd += Double(r.reviewDays)
            lp += Double(r.lapses)
            st += r.endS
            if i == 0 { firstDays = r.days }
        }
        let k = Double(runs)
        print(String(format: "| %@ | %.1f | %.1f | %.2f | %@ | %.0f |", name, sh / k, rd / k, lp / k, runs == 1 ? firstDays.map(String.init).joined(separator: " ") : "(random)", st / k))
    }
}

let n = 20000
print("First intervals, default FSRS-6, steps 2, target 0.9 (days; 'learning' = same day):")
for g in [Grade.hard, .good, .easy] {
    let m = fsrs.review(nil, elapsedDays: 0, grade: g)
    print("  first \(g): S0=\(String(format: "%.3f", m.stability)) D0=\(String(format: "%.2f", m.difficulty)) -> \(g == .easy ? "\(interval(m.stability)) d" : "learning")")
}
let g2 = fsrs.review(fsrs.review(nil, elapsedDays: 0, grade: .good), elapsedDays: 0, grade: .good)
print("  Good, Good same day: S=\(String(format: "%.3f", g2.stability)) -> \(interval(g2.stability)) d")
let pol3: [(String, Pol)] = [("Good always", .good), ("Easy on first showing, then Good", .easyFirst), ("Easy always", .easy)]
report("Familiar word, always recalled (p = 1)", pol3, p: 1.0, n: n)
report("Familiar word, recalled 95 % of attempts", pol3, p: 0.95, n: n)
let polH: [(String, Pol)] = [("Good always", .good), ("Hard on first showing, then Good", .hardFirst), ("Hard always when recalled", .hard)]
report("Hard word, always recalled with effort (p = 1)", polH, p: 1.0, n: n)
report("Hard word, recalled 85 % of attempts", polH, p: 0.85, n: n)
// Cost of a wrong Easy: a word whose real memory is what a Good would give (S = 2.307 d) is asked again after the Easy interval.
let sg = fsrs.initialStability(.good)
let se = fsrs.initialStability(.easy)
let d8 = interval(se)
print(String(format: "\nWrong Easy: real S = %.2f d (a Good), asked after %d d (the Easy interval): recall chance %.0f %% instead of 90 %%.", sg, d8, 100 * fsrs.retrievability(elapsedDays: Double(d8), stability: sg)))
let sh = fsrs.initialStability(.hard)
let dg = interval(sg)
print(String(format: "Wrong Hard: real S = %.2f d (a Good), asked after the Hard interval of %d d: recall chance %.0f %%.", sg, interval(sh), 100 * fsrs.retrievability(elapsedDays: Double(interval(sh)), stability: sg)))
_ = dg
