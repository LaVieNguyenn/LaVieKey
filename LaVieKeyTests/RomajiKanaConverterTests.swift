//
//  RomajiKanaConverterTests.swift
//  LaVieKeyTests
//
//  Golden tests for the phase-1 romaji → kana state machine.
//

import XCTest
@testable import LaVieKey

final class RomajiKanaConverterTests: XCTestCase {

    private func type(_ input: String, katakana: Bool = false, flush: Bool = true) -> String {
        var converter = RomajiKanaConverter()
        converter.script = katakana ? .katakana : .hiragana
        for ch in input { converter.input(ch) }
        if flush { converter.flushPending() }
        return converter.displayText
    }

    func testBasicSyllables() {
        XCTAssertEqual(type("a"), "あ")
        XCTAssertEqual(type("ka"), "か")
        XCTAssertEqual(type("arigatou"), "ありがとう")
        XCTAssertEqual(type("sushi"), "すし")
        XCTAssertEqual(type("fuji"), "ふじ")
    }

    func testSokuon() {
        XCTAssertEqual(type("gakkou"), "がっこう")
        XCTAssertEqual(type("zasshi"), "ざっし")
        XCTAssertEqual(type("kitte"), "きって")
        XCTAssertEqual(type("ippai"), "いっぱい")
        XCTAssertEqual(type("matcha"), "まっちゃ")  // Hepburn tch
    }

    func testNRules() {
        XCTAssertEqual(type("shinbun"), "しんぶん")
        XCTAssertEqual(type("konnichiha"), "こんにちは")  // nn + vowel → ん + な-row
        XCTAssertEqual(type("onna"), "おんな")
        XCTAssertEqual(type("minna"), "みんな")
        XCTAssertEqual(type("sensei"), "せんせい")
        XCTAssertEqual(type("kani"), "かに")
        XCTAssertEqual(type("kanni"), "かんに")
        XCTAssertEqual(type("nn"), "ん")
        XCTAssertEqual(type("n'"), "ん")
        XCTAssertEqual(type("hon"), "ほん")     // trailing n resolves at flush
        XCTAssertEqual(type("honn"), "ほん")    // doubled trailing n absorbed
        // Mid-typing (no flush): trailing n is still pending romaji
        XCTAssertEqual(type("hon", flush: false), "ほn")
    }

    func testYouon() {
        XCTAssertEqual(type("kyou"), "きょう")
        XCTAssertEqual(type("ryokou"), "りょこう")
        XCTAssertEqual(type("jagaimo"), "じゃがいも")
        XCTAssertEqual(type("chotto"), "ちょっと")
        XCTAssertEqual(type("shashin"), "しゃしん")
    }

    func testKatakanaAndChoonpu() {
        XCTAssertEqual(type("ko-hi-", katakana: true), "コーヒー")
        XCTAssertEqual(type("konpyu-ta-", katakana: true), "コンピューター")
        XCTAssertEqual(type("banana", katakana: true), "バナナ")
    }

    func testLiteralFallback() {
        XCTAssertEqual(type("q"), "q")
        XCTAssertEqual(type("wq"), "wq")
    }

    func testPunctuation() {
        XCTAssertEqual(type("desu."), "です。")
        XCTAssertEqual(type("hai,"), "はい、")
    }

    func testSmallKana() {
        XCTAssertEqual(type("xtu"), "っ")
        XCTAssertEqual(type("thi"), "てぃ")
        XCTAssertEqual(type("fanta"), "ふぁんた")
    }

    func testBackspaceRemovesOneDisplayedCharacter() {
        var converter = RomajiKanaConverter()
        for ch in "kyo" { converter.input(ch) }  // きょ
        XCTAssertTrue(converter.backspace())
        XCTAssertEqual(converter.displayText, "き")
        XCTAssertTrue(converter.backspace())
        XCTAssertEqual(converter.displayText, "")
        XCTAssertFalse(converter.backspace())  // empty → pass through
    }

    func testEngineDiffs() {
        let engine = JapaneseEngine()
        // "ka": 'k' shows k, 'a' replaces it with か
        var r = engine.processCharacter("k")
        XCTAssertEqual(r.backspaceCount, 0)
        XCTAssertEqual(r.insert, "k")
        r = engine.processCharacter("a")
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.insert, "か")
        // Word break with pending n: "hon" + space resolves ほn → ほん
        _ = engine.processCharacter("n")   // かn... n pending? ("かn")
        let flush = engine.endSegment()
        XCTAssertEqual(flush.backspaceCount, 1)
        XCTAssertEqual(flush.insert, "ん")
    }
}
