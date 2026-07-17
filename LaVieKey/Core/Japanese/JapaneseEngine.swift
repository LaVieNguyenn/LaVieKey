//
//  JapaneseEngine.swift
//  LaVieKey
//
//  Phase-1 Japanese input: wraps RomajiKanaConverter and turns its state
//  changes into (backspaceCount, insertText) diffs for CharacterInjector —
//  the same output contract the Vietnamese engine uses.
//

import Foundation

final class JapaneseEngine {

    struct Result {
        let backspaceCount: Int
        let insert: String
        var isNoOp: Bool { backspaceCount == 0 && insert.isEmpty }
    }

    private var converter = RomajiKanaConverter()

    /// Keep segments bounded: once the visible segment grows past this, the
    /// engine forgets its history (the text on screen is final anyway).
    private let segmentCap = 60

    // MARK: - Options (mirrors Preferences)

    var script: KanaScript {
        get { converter.script }
        set {
            guard converter.script != newValue else { return }
            // Script switch starts a fresh segment — already-typed kana stays.
            converter.reset()
            converter.script = newValue
        }
    }

    var japanesePunctuation: Bool {
        get { converter.japanesePunctuation }
        set { converter.japanesePunctuation = newValue }
    }

    // MARK: - Key processing

    /// Feed one printable character; returns the display diff to inject.
    func processCharacter(_ ch: Character) -> Result {
        let old = converter.displayText
        converter.input(ch)
        let result = diff(from: old, to: converter.displayText)
        if converter.displayText.count > segmentCap {
            converter.reset()
        }
        return result
    }

    /// Sync internal state for a backspace. The key itself is passed through
    /// (the app deletes exactly one displayed character, which matches one
    /// Character removed from displayText).
    func noteBackspace() {
        _ = converter.backspace()
    }

    /// Word break (space/enter/nav): resolve the pending tail (e.g. trailing
    /// "n" → ん) and start a new segment. Returns the diff to inject BEFORE
    /// the breaking key is passed through.
    func endSegment() -> Result {
        let old = converter.displayText
        converter.flushPending()
        let result = diff(from: old, to: converter.displayText)
        converter.reset()
        return result
    }

    /// Drop segment state without touching what is on screen (cursor moved,
    /// app switch, click…).
    func reset() {
        converter.reset()
    }

    // MARK: - Diff

    private func diff(from old: String, to new: String) -> Result {
        let oldChars = Array(old)
        let newChars = Array(new)
        var common = 0
        while common < min(oldChars.count, newChars.count), oldChars[common] == newChars[common] {
            common += 1
        }
        return Result(
            backspaceCount: oldChars.count - common,
            insert: String(newChars[common...])
        )
    }
}
