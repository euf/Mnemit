import Foundation

/// The word a Greek card is about, written so that two decks spelling it differently still
/// agree: the lemma in lower case, and the article that goes with it. `Card.note` is a word key
/// written out (`lemma#article`), and so is `LessonWords.note(forGreek:)`.
///
/// The lemma is the text before the first comma, semicolon with a space after it (a bare one
/// is the Greek question mark), ` / `, ` · `, opening bracket or ` -`, and before a trailing
/// group of endings such as `-ή-ό`; hyphens inside a word stay. Accents stay: Greek stress
/// separates words (πώς, πως). The article counts, so `κύριος` and `ο κύριος` are two words;
/// the common-gender `ο/η` (or `η/ο`) matches `ο` and `η` of the same lemma.
///
/// `same(as:)` says two keys are one word. `looksLike(_:)` says they would be but for accents:
/// a mistyped or missing accent (άπλος and απλός). That one only informs, as stress also
/// separates words, so what it finds is shown to the learner and never decided for them.
///
/// Only Greek: a note or a question without Greek letters has no key (`init?(card:)`), as the
/// notes of an Anki import are random strings. ponytail: one word for many languages needs
/// another way to tell a word key from an Anki guid.
public struct WordKey: Hashable, Sendable {
    /// The lemma, lower case, composed, without endings and brackets; never empty.
    public let lemma: String
    /// The article the lemma goes with, `""` for none.
    public let article: String

    /// The leading articles, longest first so that `ο/η` is not read as `ο`. The indefinite
    /// ones are those `LegacyAnswer.articles` of `deck-from-tsv` knows.
    private static let articles = ["ο/η", "η/ο", "ο", "η", "το", "οι", "τα", "ένας", "μια", "μία", "ένα"]
    private static let commonGender: Set = ["ο/η", "η/ο"]
    /// The key of `text`: a word key as `Card.note` has it (`lemma#article`, from older decks
    /// also with endings and alternatives after the lemma, or with an article in front), or
    /// Greek as typed ("η παρέα", "απλός, -ή, -ό"). `nil` if no lemma is left.
    public init?(_ text: String) {
        // Not `lowercased()`: only Foundation's version writes a final sigma as ς.
        var word = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: nil).precomposedStringWithCanonicalMapping
        var article = ""
        let hash = word.lastIndex(of: "#")
        let suffix = hash.map { String(word[word.index(after: $0)...]) }
        if let hash, let suffix, suffix.isEmpty || Self.articles.contains(suffix) {
            article = suffix
            word = String(word[..<hash])
        } else if let leading = Self.articles.first(where: { word.hasPrefix($0 + " ") }) {
            article = leading
            word.removeFirst(leading.count + 1)
        }
        let lemma = Self.withoutEndings(word[..<Self.lemmaEnd(in: word)].trimmingCharacters(in: .whitespacesAndNewlines))
        guard !lemma.isEmpty else { return nil }
        self.lemma = lemma
        self.article = article
    }

    /// The key of the word a card is about: its note, or the question of a card whose note
    /// has no Greek letters (none, or the random string of an Anki note); `nil` if neither has.
    public init?(card: Card) {
        guard let text = [card.note, card.question].compactMap(\.self).first(where: \.hasGreekLetters) else { return nil }
        self.init(text)
    }

    /// The key written as a note: `lemma#article`, the lemma alone without an article.
    public var note: String {
        article.isEmpty ? lemma : lemma + "#" + article
    }

    /// Whether the two are one word: the same lemma and compatible articles.
    public func same(as other: WordKey) -> Bool {
        !Set(sameKeys).isDisjoint(with: other.sameKeys)
    }

    /// Whether the two are not one word but have the same lemma once accents and diacritics
    /// are left out, with compatible articles.
    public func looksLike(_ other: WordKey) -> Bool {
        !same(as: other) && !Set(looseKeys).isDisjoint(with: other.looseKeys)
    }

    /// The strings under which the word is looked up: two keys are one word when they share
    /// one. `ο/η` has the keys of `ο` and `η`.
    public var sameKeys: [String] { Self.keys(lemma, article) }

    /// The same without accents and diacritics.
    var looseKeys: [String] { Self.keys(CardSearchIndex.fold(lemma), article) }

    private static func keys(_ lemma: String, _ article: String) -> [String] {
        commonGender.contains(article) ? [lemma + "#ο", lemma + "#η"] : [lemma + "#" + article]
    }

    /// Where the lemma of `word` ends: at the first `,` or `(`, `; `, ` -`, ` / ` or ` · `. One pass over
    /// the scalars: a search for each of them costs three times the rest of the key.
    private static func lemmaEnd(in word: String) -> String.Index {
        let scalars = word.unicodeScalars
        func scalar(after index: String.Index) -> (next: String.Index, scalar: Unicode.Scalar?) {
            let next = scalars.index(after: index)
            return (next, next < scalars.endIndex ? scalars[next] : nil)
        }
        var index = scalars.startIndex
        while index < scalars.endIndex {
            let (next, following) = scalar(after: index)
            switch scalars[index] {
            case ",", "(":
                return index
            case ";" where following == " ":
                return index
            case " " where following == "-":
                return index
            case " " where following == "/" || following == "·":
                if scalar(after: next).scalar == " " { return index }
            default:
                break
            }
            index = next
        }
        return scalars.endIndex
    }

    /// `lemma` without a trailing group of endings: "απλός-ή-ό" is "απλός". A hyphen inside a
    /// word stays: what follows it has to be an ending, one to three letters.
    private static func withoutEndings(_ lemma: String) -> String {
        var lemma = Substring(lemma)
        while let dash = lemma.lastIndex(of: "-"), dash != lemma.startIndex {
            let ending = lemma[lemma.index(after: dash)...]
            guard (1...3).contains(ending.count), ending.allSatisfy(\.isLetter) else { break }
            lemma = lemma[..<dash]
        }
        return String(lemma)
    }

    /// Which word each key stands for, as an index: keys that are one word, directly or
    /// through a third (`ο` and `η` of one lemma through an `ο/η`), get the same number.
    public static func groups(of keys: [WordKey]) -> [Int] {
        var parent = Array(keys.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while parent[index] != index {
                parent[index] = parent[parent[index]]
                index = parent[index]
            }
            return index
        }
        var owner: [String: Int] = [:]
        for (index, key) in keys.enumerated() {
            for string in key.sameKeys {
                if let other = owner[string] {
                    parent[root(index)] = root(other)
                } else {
                    owner[string] = index
                }
            }
        }
        return keys.indices.map(root)
    }
}

extension String {
    /// Whether the text has Greek letters, of the modern alphabet or the polytonic one.
    var hasGreekLetters: Bool {
        unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x1F00...0x1FFF).contains($0.value) }
    }
}
