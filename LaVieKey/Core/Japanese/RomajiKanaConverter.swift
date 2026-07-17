//
//  RomajiKanaConverter.swift
//  LaVieKey
//
//  Wapuro-style romaji → kana state machine (phase 1 of Japanese input).
//
//  Model: the user types romaji; unresolved romaji stays visible after the
//  kana already produced ("k" shows as k, then "ka" collapses to か).
//  The converter only tracks state; the caller diffs displayText between
//  keystrokes to compute backspace+insert for CharacterInjector.
//

import Foundation

// KanaScript enum lives in Core/Models/Preferences.swift (compiled into both
// targets); this file is app-target-only.

struct RomajiKanaConverter {

    // MARK: - State

    /// Kana (and committed literals) already produced, in display order
    private(set) var composed: String = ""
    /// Romaji tail not yet resolved into kana (still displayed as latin)
    private(set) var pending: String = ""

    var script: KanaScript = .hiragana

    /// Whether to map . , ? ! to Japanese punctuation (。、？！)
    var japanesePunctuation: Bool = true

    /// What the user currently sees for this segment
    var displayText: String {
        composed + pending
    }

    var isEmpty: Bool { composed.isEmpty && pending.isEmpty }

    // MARK: - Input

    /// Feed one typed character. Mutates state; caller diffs displayText.
    mutating func input(_ rawChar: Character) {
        let c = Character(rawChar.lowercased())

        // Non-letter input: resolve what we can, then append the mapped literal.
        guard c.isLetter, c.isASCII else {
            if c == "'" && pending == "n" {
                // n' → ん (explicit ん separator)
                composed += kana("ん")
                pending = ""
                return
            }
            if c == "-" {
                // Chōonpu in both scripts (wapuro convention)
                flushPendingAsLiteral()
                composed += "ー"
                return
            }
            flushPendingAsLiteral()
            composed += String(mapPunctuation(rawChar))
            return
        }

        // ん before a consonant: "n" + consonant (except y and vowels).
        // Includes c == "n": the SECOND n stays pending (MS-IME behavior), so
        // "onna" → おんな and "konnichiha" → こんにちは. A trailing doubled n
        // ("honn") is absorbed at flush time instead (see flushPending).
        if pending == "n", !"aiueoy".contains(c) {
            composed += kana("ん")
            pending = ""
            if c == "n" {
                pending = "n"
                return
            }
            // fall through: process c fresh below
        }

        // Sokuon: doubled consonant (kk, tt, pp… but not nn/vowels)
        if let last = pending.last, last == c, !"aiueon".contains(c) {
            composed += kana("っ")
            pending = String(c)
            return
        }

        // Hepburn "tch" → っち (matcha → まっちゃ)
        if pending == "t", c == "c" {
            composed += kana("っ")
            pending = "c"
            return
        }

        pending.append(c)
        resolvePending()
    }

    /// Backspace over the DISPLAYED text: removes one pending romaji letter,
    /// or (when nothing is pending) one composed kana/literal character.
    /// Returns false when the segment was already empty (caller passes the
    /// key through to the app).
    mutating func backspace() -> Bool {
        if !pending.isEmpty {
            pending.removeLast()
            return true
        }
        if !composed.isEmpty {
            composed.removeLast()
            return true
        }
        return false
    }

    /// Resolve the pending tail at a word break (space/enter/punctuation):
    /// a lone trailing "n" becomes ん; other unresolved romaji stays literal.
    mutating func flushPending() {
        flushPendingAsLiteral()
    }

    /// End the segment (word break / commit): unresolved romaji stays as-is.
    mutating func reset() {
        composed = ""
        pending = ""
    }

    // MARK: - Resolution

    private mutating func resolvePending() {
        while !pending.isEmpty {
            if let kanaValue = Self.table[pending] {
                composed += kana(kanaValue)
                pending = ""
                return
            }
            if Self.prefixes.contains(pending) {
                return  // could still become a longer syllable — keep waiting
            }
            // Dead prefix: the FIRST letter can never start a match anymore.
            // Move it out as a literal and retry the remainder (e.g. "qk" → "q" + retry "k").
            let first = pending.removeFirst()
            composed += String(first)
        }
    }

    /// Commit unresolved romaji as literal latin (segment end / punctuation)
    private mutating func flushPendingAsLiteral() {
        if pending == "n" {
            // "honn"/"nn": the pending n is the explicit FINISHER of the ん we
            // already emitted — absorb it. Otherwise a lone trailing n is ん.
            if composed.hasSuffix("ん") || composed.hasSuffix("ン") {
                // absorbed — nothing to append
            } else {
                composed += kana("ん")
            }
        } else {
            composed += pending
        }
        pending = ""
    }

    /// Convert hiragana string to the active script
    private func kana(_ hiragana: String) -> String {
        guard script == .katakana else { return hiragana }
        return String(hiragana.unicodeScalars.map { scalar -> Character in
            // ぁ (U+3041) … ゖ (U+3096) → ァ (U+30A1) … ヶ (U+30F6)
            if (0x3041...0x3096).contains(scalar.value),
               let shifted = Unicode.Scalar(scalar.value + 0x60) {
                return Character(shifted)
            }
            return Character(scalar)
        })
    }

    private func mapPunctuation(_ c: Character) -> Character {
        guard japanesePunctuation else { return c }
        switch c {
        case ".": return "。"
        case ",": return "、"
        case "?": return "？"
        case "!": return "！"
        case "[": return "「"
        case "]": return "」"
        default: return c
        }
    }

    // MARK: - Romaji table (wapuro / Hepburn + common variants)

    static let table: [String: String] = [
        // Vowels
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        // K
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ", "kye": "きぇ",
        // G
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
        // S
        "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
        "sha": "しゃ", "shu": "しゅ", "sho": "しょ", "she": "しぇ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        // Z
        "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "je": "じぇ",
        "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "zya": "じゃ", "zyu": "じゅ", "zyo": "じょ",
        // T
        "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
        "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "che": "ちぇ",
        "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
        "thi": "てぃ", "thu": "てゅ",
        "twu": "とぅ",
        // D
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
        "dhi": "でぃ", "dhu": "でゅ",
        "dwu": "どぅ",
        // N
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
        // H
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ", "fyu": "ふゅ",
        // B
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "bya": "びゃ", "byu": "びゅ", "byo": "びょ",
        // P
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
        // M
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "mya": "みゃ", "myu": "みゅ", "myo": "みょ",
        // Y
        "ya": "や", "yu": "ゆ", "yo": "よ", "ye": "いぇ",
        // R
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
        // W
        "wa": "わ", "wo": "を", "wi": "うぃ", "we": "うぇ",
        // V
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        // Small kana (x/l prefixes)
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
        "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
        "xtu": "っ", "ltu": "っ", "xtsu": "っ", "ltsu": "っ",
        "xwa": "ゎ", "lwa": "ゎ",
        "xke": "ゖ", "xka": "ゕ",
    ]

    /// All strict prefixes of table keys (precomputed for O(1) prefix checks)
    static let prefixes: Set<String> = {
        var set = Set<String>()
        for key in table.keys {
            var prefix = ""
            for ch in key.dropLast() {
                prefix.append(ch)
                set.insert(prefix)
            }
        }
        return set
    }()
}
