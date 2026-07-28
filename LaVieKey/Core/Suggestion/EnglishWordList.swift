//
//  EnglishWordList.swift
//  LaVieKey
//
//  Frequency-ranked English word list for the inline suggestion feature.
//  Source: google-10000-english (bundled as Resources/english-words.txt,
//  one word per line, most frequent first).
//

import Foundation

struct EnglishWordList {

    /// Words in frequency order (rank 0 = most frequent)
    private let words: [String]

    /// Word → rank, for O(1) exact-match checks
    private let rankByWord: [String: Int]

    init(words: [String]) {
        self.words = words
        var ranks: [String: Int] = [:]
        ranks.reserveCapacity(words.count)
        for (i, w) in words.enumerated() where ranks[w] == nil {
            ranks[w] = i
        }
        self.rankByWord = ranks
    }

    /// Load the bundled list. Returns an empty list when the resource is
    /// missing (feature silently disables itself).
    static func loadBundled() -> EnglishWordList {
        guard let url = Bundle.main.url(forResource: "english-words", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return EnglishWordList(words: [])
        }
        let list = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return EnglishWordList(words: list)
    }

    var isEmpty: Bool { words.isEmpty }

    /// True when `word` is itself a known English word
    func contains(_ word: String) -> Bool {
        rankByWord[word] != nil
    }

    /// Best suggestion for a typed prefix.
    ///
    /// Ranking is NOT pure frequency: a frequent long word would otherwise
    /// bury the shorter word the user is actually typing — "origi" would
    /// suggest "original" (rank 628) over "origin" (rank 2385), and worse,
    /// typing "origin" in full would still suggest "original".
    /// Score = rank × (1 + extraChars)², lower wins: an extra character must
    /// be "paid for" by being substantially more frequent, and an exact match
    /// (extraChars = 0) is nearly always preferred.
    ///
    /// Linear scan over ~10k short strings is well under 1ms — no index needed.
    func bestMatch(forPrefix prefix: String) -> String? {
        topMatches(forPrefix: prefix, limit: 1).first
    }

    /// Top `limit` completions for `prefix`, best first, using the score above.
    /// - Parameter excludingExact: drop the word that equals the prefix (used
    ///   when the typed word came out intact — there is nothing to restore, so
    ///   only genuine extensions are worth offering: "hell" → hello, …).
    func topMatches(forPrefix prefix: String, limit: Int, excludingExact: Bool = false) -> [String] {
        guard !prefix.isEmpty, limit > 0 else { return [] }

        var scored: [(word: String, score: Int)] = []
        for (rank, word) in words.enumerated() where word.hasPrefix(prefix) {
            if excludingExact && word == prefix { continue }
            let extra = word.count - prefix.count
            let penalty = (1 + extra) * (1 + extra)
            scored.append((word, (rank + 1) * penalty))
        }
        return scored.sorted { $0.score < $1.score }
            .prefix(limit)
            .map(\.word)
    }
}
