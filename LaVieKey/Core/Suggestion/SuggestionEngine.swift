//
//  SuggestionEngine.swift
//  LaVieKey
//
//  English inline-suggestion logic (VS Code-style): rescues Telex-mangled
//  words ("origi" shown as "ỏigi" → origin) AND completes half-typed ones
//  ("hell" → hello). Offers up to 3 candidates; the caller navigates with the
//  arrow keys and accepts with Tab.
//
//  Keeps its OWN raw-keystroke buffer for the current word, fed by
//  KeyboardEventHandler (the Vietnamese engine does not expose one). The
//  displayed-character count for the accept comes from `engine.index`.
//

import Foundation

struct Suggestion: Equatable {
    /// Raw typed prefix (lowercased), e.g. "origi"
    let typedPrefix: String
    /// Full suggested word, e.g. "origin"
    let word: String
    /// Word adjusted to the user's capitalization (first letter uppercase
    /// when the word was started with Shift)
    let displayWord: String
}

/// What the panel should render: candidates plus which one is selected
struct SuggestionSet: Equatable {
    let candidates: [Suggestion]
    let selectedIndex: Int

    var selected: Suggestion? {
        candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
    }
}

final class SuggestionEngine {

    /// Loaded on first use: the word list costs a few MB and most users never
    /// switch the suggestion feature on.
    private lazy var wordList: EnglishWordList = wordListProvider()
    private let wordListProvider: () -> EnglishWordList

    /// Raw ASCII letters typed since the last word break (lowercased)
    private var rawWord: String = ""

    /// Whether the first letter of the word was typed uppercase
    private var startedUppercase = false

    /// Index the user moved to with the arrow keys; reset on every new keystroke
    private var selectedIndex = 0

    /// How many characters this word currently occupies on screen
    private(set) var displayedCount = 0

    /// (raw prefix, on-screen length) after each keystroke. Backspace rewinds
    /// to the entry matching the new on-screen length — a plain "drop one raw
    /// character" desynchronises as soon as a tone key adds a keystroke without
    /// adding a character ("kear" is 4 keys but 3 characters), which left stale
    /// letters glued to the next word.
    private var history: [(raw: String, displayed: Int)] = []

    /// Minimum raw prefix length before suggesting (avoid noise on short words)
    private let minPrefixLength = 3

    /// How many candidates to offer
    private let maxCandidates = 3

    init(wordList: @autoclosure @escaping () -> EnglishWordList = .loadBundled()) {
        self.wordListProvider = wordList
    }

    // MARK: - Feeding keystrokes (called from KeyboardEventHandler, VN mode)

    /// Record one typed letter together with how many characters it added to
    /// (or removed from) the screen.
    func noteLetter(_ ch: Character, isUppercase: Bool, displayedDelta: Int) {
        guard ch.isLetter, ch.isASCII else {
            reset()
            return
        }
        if rawWord.isEmpty {
            startedUppercase = isUppercase
        }
        rawWord.append(Character(ch.lowercased()))
        displayedCount = max(0, displayedCount + displayedDelta)
        history.append((rawWord, displayedCount))
        selectedIndex = 0   // new keystroke → back to the best candidate
    }

    /// One character was deleted from the screen: rewind the raw prefix to the
    /// last state that had that many characters on screen.
    func noteBackspace() {
        displayedCount = max(0, displayedCount - 1)
        selectedIndex = 0

        guard displayedCount > 0 else {
            reset()   // screen is empty for this word → nothing may carry over
            return
        }
        while let last = history.last, last.displayed > displayedCount {
            history.removeLast()
        }
        rawWord = history.last?.raw ?? ""
        if rawWord.isEmpty { reset() }
    }

    /// Raw prefix currently accumulated (diagnostics only)
    var debugRawWord: String { rawWord }

    /// Keys that Telex overloads: pressing one twice in a row means "I meant
    /// the plain letter" (tone keys s f r x j z, ư/ơ/ă key w, and the doubling
    /// vowels/đ a e o d). Collapsing each such pair back to a single letter
    /// recovers the English word the user was actually typing:
    /// "exxperience" → "experience", "wwas" → "was", "neeed" → "need",
    /// "adddresss" → "address". Letters outside this set are untouched, so
    /// "hello" keeps both l's.
    private static let telexEscapeKeys: Set<Character> = ["a", "e", "o", "d", "s", "f", "r", "x", "j", "z", "w"]

    static func collapsingTelexEscapes(_ word: String) -> String {
        var result = ""
        var index = word.startIndex
        while index < word.endIndex {
            let ch = word[index]
            let next = word.index(after: index)
            if telexEscapeKeys.contains(ch), next < word.endIndex, word[next] == ch {
                result.append(ch)          // pair → single letter
                index = word.index(after: next)
            } else {
                result.append(ch)
                index = next
            }
        }
        return result
    }

    /// Word break / cursor move / app switch — start over
    func reset() {
        rawWord = ""
        startedUppercase = false
        selectedIndex = 0
        displayedCount = 0
        history.removeAll(keepingCapacity: true)
    }

    // MARK: - Navigation

    /// Move the highlight by `delta` (wraps around). No-op when there is
    /// nothing to move through.
    func moveSelection(by delta: Int, candidateCount: Int) {
        guard candidateCount > 1 else { return }
        selectedIndex = ((selectedIndex + delta) % candidateCount + candidateCount) % candidateCount
    }

    // MARK: - Suggestion

    /// Current candidate set, or nil when the panel should be hidden.
    ///
    /// - Parameter wordWasTransformed: whether the Vietnamese engine changed
    ///   anything for this word. When it did, the word as typed is itself a
    ///   valid candidate (restoring "ỏigi" → "origi"); when it did not, only
    ///   genuine completions are offered ("hell" → hello, …).
    func currentSuggestions(wordWasTransformed: Bool) -> SuggestionSet? {
        guard !wordList.isEmpty else { return nil }
        guard rawWord.count >= minPrefixLength else { return nil }

        // Try the keys as typed first, then the same keys with Telex escapes
        // collapsed. Typing an English "x" requires pressing x twice (the first
        // press is the tilde tone), so "experience" reaches us as
        // "exxperience" — a string no dictionary contains.
        var searchPrefix = rawWord
        var matches = wordList.topMatches(
            forPrefix: rawWord,
            limit: maxCandidates,
            excludingExact: !wordWasTransformed
        )
        if matches.isEmpty {
            let collapsed = Self.collapsingTelexEscapes(rawWord)
            if collapsed != rawWord, collapsed.count >= minPrefixLength {
                let alt = wordList.topMatches(
                    forPrefix: collapsed,
                    limit: maxCandidates,
                    excludingExact: !wordWasTransformed
                )
                if !alt.isEmpty {
                    searchPrefix = collapsed
                    matches = alt
                }
            }
        }
        guard !matches.isEmpty else { return nil }

        let candidates = matches.map { match in
            Suggestion(
                typedPrefix: searchPrefix,
                word: match,
                displayWord: startedUppercase
                    ? match.prefix(1).uppercased() + match.dropFirst()
                    : match
            )
        }

        let index = min(selectedIndex, candidates.count - 1)
        selectedIndex = index
        return SuggestionSet(candidates: candidates, selectedIndex: index)
    }
}
