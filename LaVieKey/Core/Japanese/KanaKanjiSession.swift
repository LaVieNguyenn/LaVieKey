//
//  KanaKanjiSession.swift
//  LaVieKey
//
//  The 変換 (conversion) state machine: once kana is on screen, Space looks it
//  up in SKKDictionary and the user walks the candidate list.
//
//  Key handling while a session is active:
//      Space / ↓   next candidate
//      ↑           previous candidate
//      1…9         pick directly
//      Enter       commit the highlighted candidate
//      Esc         cancel, restore the kana
//      anything    commit, then the key is handled normally
//

import Foundation

final class KanaKanjiSession {

    struct State: Equatable {
        let reading: String        // kana being converted, e.g. "かんじ"
        let candidates: [String]   // 漢字, 幹事, …
        let selectedIndex: Int

        var selected: String? {
            candidates.indices.contains(selectedIndex) ? candidates[selectedIndex] : nil
        }
    }

    private(set) var state: State?

    var isActive: Bool { state != nil }

    /// What is currently drawn in the target app for this session — the kana
    /// at first, then whichever candidate is highlighted. Needed to compute
    /// how many characters to delete on the next change.
    private(set) var displayedText: String = ""

    private let dictionary: SKKDictionary
    private let learning: JapaneseLearning

    init(dictionary: SKKDictionary = .shared, learning: JapaneseLearning = .shared) {
        self.dictionary = dictionary
        self.learning = learning
    }

    // MARK: - Starting

    /// Try to start a conversion for `reading`. Returns false when the
    /// dictionary has nothing — the caller then lets Space through as a space.
    func start(reading: String) -> Bool {
        guard !reading.isEmpty else { return false }
        // User entries and previously chosen candidates float to the top
        let candidates = learning.rank(dictionary.candidates(for: reading), for: reading)
        guard !candidates.isEmpty else { return false }

        state = State(reading: reading, candidates: candidates, selectedIndex: 0)
        displayedText = reading
        return true
    }

    // MARK: - Navigating

    /// Move the highlight. Wraps around, mirroring the candidate window.
    func moveSelection(by delta: Int) {
        guard let current = state, current.candidates.count > 1 else { return }
        let count = current.candidates.count
        let next = ((current.selectedIndex + delta) % count + count) % count
        state = State(reading: current.reading, candidates: current.candidates, selectedIndex: next)
    }

    /// Pick by number key (1-based as printed in the window)
    func select(number: Int) -> Bool {
        guard let current = state else { return false }
        let index = number - 1
        guard current.candidates.indices.contains(index) else { return false }
        state = State(reading: current.reading, candidates: current.candidates, selectedIndex: index)
        return true
    }

    // MARK: - Finishing

    /// Text that should replace what is on screen right now, or nil when it is
    /// already correct.
    func pendingReplacement() -> (backspaces: Int, insert: String)? {
        guard let selected = state?.selected, selected != displayedText else { return nil }
        let backspaces = displayedText.count
        displayedText = selected
        return (backspaces, selected)
    }

    /// Accept the highlighted candidate and end the session.
    func commit() -> String? {
        defer { end() }
        guard let current = state, let selected = current.selected else { return nil }
        learning.record(reading: current.reading, candidate: selected)
        return selected
    }

    /// Abandon the conversion, restoring the original kana.
    /// Returns the replacement needed to undo the preview, if any.
    func cancel() -> (backspaces: Int, insert: String)? {
        guard let reading = state?.reading else { end(); return nil }
        let needsRestore = displayedText != reading
        let result = needsRestore ? (displayedText.count, reading) : nil
        end()
        return result
    }

    func end() {
        state = nil
        displayedText = ""
    }
}
