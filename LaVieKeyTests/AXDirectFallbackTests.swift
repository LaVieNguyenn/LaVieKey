//
//  AXDirectFallbackTests.swift
//  LaVieKeyTests
//
//  Test case simulating the AX Direct fallback bug in Firefox
//  Bug: Typing "dịch" (d + i + j + c + h) produces "diịch" in Firefox Content Area
//  Root cause: When AX Direct fails, fallback uses Shift+Left (selection) which
//  Firefox doesn't reliably process, so the original 'i' is not replaced by 'ị'
//

import XCTest
@testable import LaVieKey

// MARK: - Mock Screen Buffer

/// Simulates what the user sees on screen
/// Tracks text content and cursor position to verify injection correctness
class MockScreenBuffer {
    var text: String = ""
    var cursorPosition: Int = 0
    
    /// Insert a character at cursor position (simulates normal keystroke)
    func insertCharacter(_ char: String) {
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert(contentsOf: char, at: index)
        cursorPosition += char.count
    }
    
    /// Delete `count` characters before cursor (simulates backspace)
    func backspace(count: Int) {
        let deleteCount = min(count, cursorPosition)
        let start = text.index(text.startIndex, offsetBy: cursorPosition - deleteCount)
        let end = text.index(text.startIndex, offsetBy: cursorPosition)
        text.removeSubrange(start..<end)
        cursorPosition -= deleteCount
    }
    
    /// Select `count` characters before cursor, then replace with text
    /// Returns true if selection+replace succeeded
    func selectAndReplace(selectCount: Int, replacement: String, selectionWorks: Bool) -> Bool {
        if selectionWorks {
            // Selection works: delete selected chars, insert replacement
            let deleteCount = min(selectCount, cursorPosition)
            let start = text.index(text.startIndex, offsetBy: cursorPosition - deleteCount)
            let end = text.index(text.startIndex, offsetBy: cursorPosition)
            text.removeSubrange(start..<end)
            cursorPosition -= deleteCount
            // Insert replacement
            let insertIndex = text.index(text.startIndex, offsetBy: cursorPosition)
            text.insert(contentsOf: replacement, at: insertIndex)
            cursorPosition += replacement.count
            return true
        } else {
            // Selection FAILS (Firefox bug): Shift+Left doesn't select anything
            // Text is just inserted at cursor position without replacing
            let insertIndex = text.index(text.startIndex, offsetBy: cursorPosition)
            text.insert(contentsOf: replacement, at: insertIndex)
            cursorPosition += replacement.count
            return false
        }
    }
    
    /// AX Direct: read value, manipulate, write back
    /// Returns true if AX API is available (has value attribute)
    func axDirectReplace(backspaceCount: Int, replacement: String, axAvailable: Bool) -> Bool {
        if axAvailable {
            // AX Direct works: manipulate text directly
            let deleteStart = max(0, cursorPosition - backspaceCount)
            let prefix = String(text.prefix(deleteStart))
            let suffix = String(text.dropFirst(cursorPosition))
            text = prefix + replacement + suffix
            cursorPosition = deleteStart + replacement.count
            return true
        } else {
            // AX Direct fails: no value attribute (Firefox Content Area)
            return false
        }
    }
}

// MARK: - Injection Simulation

/// Simulates the injection logic from CharacterInjector.injectSync()
/// for the .axDirect method case
class MockInjector {
    let screen: MockScreenBuffer
    var logs: [String] = []
    
    /// Whether AX API is available for this app
    var axAvailable: Bool = false
    
    /// Whether Shift+Left selection works in this app
    var selectionWorks: Bool = true
    
    /// Number of AX retry attempts
    var axRetryCount: Int = 3
    
    init(screen: MockScreenBuffer) {
        self.screen = screen
    }
    
    func log(_ message: String) {
        logs.append(message)
    }
    
    /// Simulate the axDirect injection path (as in CharacterInjector.injectSync)
    func injectViaAXDirect(backspaceCount: Int, text: String) {
        log("Inject: bs=\(backspaceCount), text=\"\(text)\", method=axDirect")
        log("    → AX Direct method: bs=\(backspaceCount), text=\"\(text)\"")
        
        // Try AX API up to axRetryCount times (mirrors injectViaAXWithFallback)
        var axSucceeded = false
        for attempt in 0..<axRetryCount {
            let success = screen.axDirectReplace(
                backspaceCount: backspaceCount,
                replacement: text,
                axAvailable: axAvailable
            )
            if success {
                log("[AX] Success: bs=\(backspaceCount), text=\(text)")
                axSucceeded = true
                break
            } else {
                log("[AX] No value attribute")
            }
        }
        
        if !axSucceeded {
            // All AX attempts failed - fallback
            log("[AX] Fallback to synthetic events")
            log("    → AX failed, fallback to selection")
            
            // Fallback: injectViaSelectionInternal + sendTextChunkedInternal
            // This is the CURRENT (buggy) behavior
            for i in 0..<backspaceCount {
                log("    → Shift+Left \(i + 1)/\(backspaceCount)")
            }
            
            // Selection + text replacement
            _ = screen.selectAndReplace(
                selectCount: backspaceCount,
                replacement: text,
                selectionWorks: selectionWorks
            )
            
            log("    → Sending text chunked: '\(text)' (handling special chars), direct=false")
        }
        
        log("injectSync: complete (AX Direct)")
    }
    
    /// Simulate the FIXED injection using backspace instead of selection
    func injectViaAXDirectFixed(backspaceCount: Int, text: String) {
        log("Inject: bs=\(backspaceCount), text=\"\(text)\", method=axDirect")
        log("    → AX Direct method: bs=\(backspaceCount), text=\"\(text)\"")
        
        // Try AX API
        var axSucceeded = false
        for _ in 0..<axRetryCount {
            let success = screen.axDirectReplace(
                backspaceCount: backspaceCount,
                replacement: text,
                axAvailable: axAvailable
            )
            if success {
                log("[AX] Success")
                axSucceeded = true
                break
            } else {
                log("[AX] No value attribute")
            }
        }
        
        if !axSucceeded {
            // FIXED: Use backspace instead of selection for fallback
            log("[AX] Fallback to backspace + text")
            screen.backspace(count: backspaceCount)
            
            let insertIndex = screen.text.index(screen.text.startIndex, offsetBy: screen.cursorPosition)
            screen.text.insert(contentsOf: text, at: insertIndex)
            screen.cursorPosition += text.count
            
            log("    → Backspace \(backspaceCount) + text '\(text)'")
        }
        
        log("injectSync: complete (AX Direct)")
    }
}

// MARK: - Test Cases

class AXDirectFallbackTests: XCTestCase {
    
    // MARK: - Bug Reproduction: Firefox "dịch" → "diịch"
    
    /// Reproduces the exact bug from the debug log:
    /// User types d-i-j-c-h expecting "dịch" but gets "diịch"
    func testFirefoxBug_dich_becomes_diich() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        // Configure as Firefox Content Area
        injector.axAvailable = false       // Firefox has no AXValue on content area
        injector.selectionWorks = false     // Shift+Left doesn't work reliably in Firefox
        
        // Step 1: Type 'd' - normal keystroke, no injection needed
        screen.insertCharacter("d")
        XCTAssertEqual(screen.text, "d")
        
        // Step 2: Type 'i' - normal keystroke
        screen.insertCharacter("i")
        XCTAssertEqual(screen.text, "di")
        
        // Step 3: Type 'j' - engine detects mark key, needs to replace 'i' → 'ị'
        // Engine output: bs=1, chars=1, text="ị"
        // Using CURRENT (buggy) injection:
        injector.injectViaAXDirect(backspaceCount: 1, text: "ị")
        
        // BUG: Screen shows "diị" instead of "dị"
        // Because Shift+Left didn't select 'i', so 'ị' was inserted next to 'i'
        XCTAssertEqual(screen.text, "diị",
            "BUG REPRODUCED: 'i' was not replaced, 'ị' inserted alongside → 'diị'")
        
        // Step 4: Type 'c' - engine says mark position correct, bs=0, chars=0
        // No injection needed (hookState restored)
        screen.insertCharacter("c")
        
        // Step 5: Type 'h' - engine says mark position correct, bs=0, chars=0
        screen.insertCharacter("h")
        
        // Final result: "diịch" instead of "dịch"
        XCTAssertEqual(screen.text, "diịch",
            "BUG: Firefox produces 'diịch' instead of 'dịch'")
        
        // Print log for debugging
        print("=== Bug Reproduction Log ===")
        for log in injector.logs {
            print(log)
        }
    }
    
    /// Verifies the correct behavior when AX Direct succeeds (e.g., Spotlight)
    func testAXDirectSuccess_dich_correct() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        // Configure as Spotlight (AX works)
        injector.axAvailable = true
        
        // Type d, i
        screen.insertCharacter("d")
        screen.insertCharacter("i")
        XCTAssertEqual(screen.text, "di")
        
        // Type 'j' → replace 'i' with 'ị' via AX Direct
        injector.injectViaAXDirect(backspaceCount: 1, text: "ị")
        XCTAssertEqual(screen.text, "dị",
            "AX Direct should correctly replace 'i' → 'ị'")
        
        // Type 'c', 'h'
        screen.insertCharacter("c")
        screen.insertCharacter("h")
        
        XCTAssertEqual(screen.text, "dịch",
            "With working AX Direct, result should be 'dịch'")
    }
    
    /// Verifies selection fallback works in apps where Shift+Left is reliable (e.g., Chrome)
    func testSelectionFallbackWorks_Chrome() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        // Configure: AX fails but selection works (Chrome edge case)
        injector.axAvailable = false
        injector.selectionWorks = true   // Shift+Left works in Chrome
        
        // Type d, i
        screen.insertCharacter("d")
        screen.insertCharacter("i")
        
        // Type 'j' → fallback to selection
        injector.injectViaAXDirect(backspaceCount: 1, text: "ị")
        XCTAssertEqual(screen.text, "dị",
            "When selection works, fallback should correctly replace 'i' → 'ị'")
        
        screen.insertCharacter("c")
        screen.insertCharacter("h")
        
        XCTAssertEqual(screen.text, "dịch")
    }
    
    // MARK: - Fix Verification
    
    /// Verifies that using backspace fallback instead of selection fixes the Firefox bug
    func testFixedFallback_Firefox_dich_correct() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        // Configure as Firefox (AX fails, selection fails)
        injector.axAvailable = false
        injector.selectionWorks = false
        
        // Type d, i
        screen.insertCharacter("d")
        screen.insertCharacter("i")
        XCTAssertEqual(screen.text, "di")
        
        // Type 'j' → FIXED fallback uses backspace instead of selection
        injector.injectViaAXDirectFixed(backspaceCount: 1, text: "ị")
        XCTAssertEqual(screen.text, "dị",
            "FIXED: Backspace fallback correctly replaces 'i' → 'ị'")
        
        screen.insertCharacter("c")
        screen.insertCharacter("h")
        
        XCTAssertEqual(screen.text, "dịch",
            "FIXED: Firefox should now produce 'dịch' correctly")
    }
    
    // MARK: - Multi-vowel Words
    
    /// Test "thuong" → "thương" (more complex: 2 vowels, mark on ơ)
    func testFirefoxBug_thuong() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        injector.axAvailable = false
        injector.selectionWorks = false
        
        // Type: t, h, u, o
        screen.insertCharacter("t")
        screen.insertCharacter("h")
        screen.insertCharacter("u")
        screen.insertCharacter("o")
        XCTAssertEqual(screen.text, "thuo")
        
        // Type 'w' → engine replaces 'o' with 'ơ' (bs=1, text="ơ")
        injector.injectViaAXDirect(backspaceCount: 1, text: "ơ")
        
        // BUG: "thuoơ" instead of "thuơ"
        XCTAssertEqual(screen.text, "thuoơ",
            "BUG: 'o' not replaced → 'thuoơ' instead of 'thuơ'")
        
        // Type 'n', 'g'
        screen.insertCharacter("n")
        screen.insertCharacter("g")
        
        XCTAssertEqual(screen.text, "thuoơng",
            "BUG: Final result 'thuoơng' instead of 'thương'")
    }
    
    /// Same word with fixed fallback
    func testFixedFallback_thuong() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        injector.axAvailable = false
        injector.selectionWorks = false
        
        screen.insertCharacter("t")
        screen.insertCharacter("h")
        screen.insertCharacter("u")
        screen.insertCharacter("o")
        
        // Type 'w' with FIXED fallback
        injector.injectViaAXDirectFixed(backspaceCount: 1, text: "ơ")
        XCTAssertEqual(screen.text, "thuơ",
            "FIXED: 'o' correctly replaced → 'thuơ'")
        
        screen.insertCharacter("n")
        screen.insertCharacter("g")
        
        XCTAssertEqual(screen.text, "thuơng",
            "FIXED: Result 'thuơng' is correct base for further processing")
    }
    
    // MARK: - Tone Mark with Multiple Backspaces
    
    /// Test tone repositioning: "toan" + 's' → needs to move tone from 'o' to 'a'
    /// Engine sends bs=2, chars=3 (replace "oá" with "oán")
    func testFirefoxBug_multipleBackspace() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        injector.axAvailable = false
        injector.selectionWorks = false
        
        // Simulate: screen already has "toá" (after typing t,o,a,s)
        // Now type 'n' → engine needs to reposition tone: "toá" → "toán"
        // Engine sends: bs=2, text="oán" (replace last 2 chars with 3 chars)
        screen.text = "toá"
        screen.cursorPosition = 3
        
        injector.injectViaAXDirect(backspaceCount: 2, text: "oán")
        
        // BUG: Selection of 2 chars fails → "toáoán" instead of "toán"
        XCTAssertEqual(screen.text, "toáoán",
            "BUG: Multiple char selection also fails → 'toáoán' instead of 'toán'")
    }
    
    /// Same test with fixed fallback
    func testFixedFallback_multipleBackspace() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        injector.axAvailable = false
        injector.selectionWorks = false
        
        screen.text = "toá"
        screen.cursorPosition = 3
        
        injector.injectViaAXDirectFixed(backspaceCount: 2, text: "oán")
        
        XCTAssertEqual(screen.text, "toán",
            "FIXED: Backspace correctly handles multiple char replacement → 'toán'")
    }
    
    // MARK: - AX Retry Behavior
    
    /// Verify that AX Direct retries 3 times before falling back
    func testAXRetries3Times() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        injector.axAvailable = false
        injector.selectionWorks = true  // Make selection work so we get correct result
        
        screen.insertCharacter("d")
        screen.insertCharacter("i")
        
        injector.injectViaAXDirect(backspaceCount: 1, text: "ị")
        
        // Count "[AX] No value attribute" log entries → should be exactly 3
        let axFailCount = injector.logs.filter { $0 == "[AX] No value attribute" }.count
        XCTAssertEqual(axFailCount, 3,
            "Should attempt AX Direct exactly 3 times before fallback")
        
        // Should have the fallback log
        XCTAssertTrue(injector.logs.contains("[AX] Fallback to synthetic events"),
            "Should log fallback after 3 AX failures")
    }
    
    // MARK: - Engine + Injection Integration
    
    /// Full integration test: Engine processes "dịch" and we verify injection commands
    func testEngine_dich_injectionCommands() {
        let engine = VNEngine()
        engine.reset()
        
        // Type 'd'
        let r1 = engine.processKey(character: "d", keyCode: VietnameseData.KEY_D, isUppercase: false)
        XCTAssertEqual(r1.backspaceCount, 0, "No backspace for 'd'")
        
        // Type 'i'
        let r2 = engine.processKey(character: "i", keyCode: VietnameseData.KEY_I, isUppercase: false)
        XCTAssertEqual(r2.backspaceCount, 0, "No backspace for 'i'")
        
        // Type 'j' (mark key for dấu nặng)
        let r3 = engine.processKey(character: "j", keyCode: VietnameseData.KEY_J, isUppercase: false)
        XCTAssertEqual(r3.backspaceCount, 1, "Should backspace 1 to replace 'i'")
        XCTAssertEqual(r3.newCharacters.count, 1, "Should send 1 new char 'ị'")
        
        // Verify the engine buffer shows correct word
        XCTAssertEqual(engine.getCurrentWord(), "dị",
            "Engine buffer should show 'dị' after d+i+j")
        
        // Type 'c'
        let r4 = engine.processKey(character: "c", keyCode: VietnameseData.KEY_C, isUppercase: false)
        // After checkMarkPosition, hookState is restored to (0,0)
        // Engine recognizes mark is already in correct position
        
        // Type 'h'
        let r5 = engine.processKey(character: "h", keyCode: VietnameseData.KEY_H, isUppercase: false)
        
        // Verify final engine state
        XCTAssertEqual(engine.getCurrentWord(), "dịch",
            "Engine buffer should show 'dịch'")
        
        // The critical injection command is at step 3 (j key):
        // bs=1, newChar=1 → this is where Firefox fails
        // If the injector can't properly delete 1 char and insert 1 char,
        // the screen will be out of sync with the engine
        print("=== Engine Injection Commands ===")
        print("d: bs=\(r1.backspaceCount), chars=\(r1.newCharacters.count)")
        print("i: bs=\(r2.backspaceCount), chars=\(r2.newCharacters.count)")
        print("j: bs=\(r3.backspaceCount), chars=\(r3.newCharacters.count) ← CRITICAL")
        print("c: bs=\(r4.backspaceCount), chars=\(r4.newCharacters.count)")
        print("h: bs=\(r5.backspaceCount), chars=\(r5.newCharacters.count)")
    }
    
    // MARK: - Log Replay
    
    /// Replay the exact sequence from the user's debug log
    /// and verify screen state at each step
    func testLogReplay_FirefoxDich() {
        let screen = MockScreenBuffer()
        let injector = MockInjector(screen: screen)
        
        // Configure exactly as in the log:
        // App: Firefox (org.mozilla.firefox)
        // Injection: axDirect (Firefox Content Area) [Chunked]
        // IMKit: markedText=true
        injector.axAvailable = false     // [AX] No value attribute × 3
        injector.selectionWorks = false  // Shift+Left doesn't work in Firefox content
        
        // [09:43:19] Engine: insertKey: keyCode=2 'd'
        screen.insertCharacter("d")
        XCTAssertEqual(screen.text, "d", "After 'd': screen='d'")
        
        // [09:43:19] Engine: insertKey: keyCode=34 'i'
        screen.insertCharacter("i")
        XCTAssertEqual(screen.text, "di", "After 'i': screen='di'")
        
        // [09:43:19] Engine: handleMarkKey: keyCode=38 'j'
        // Engine result: backspaceCount=1, newCharCount=1
        // Injection attempt:
        //   [AX] No value attribute × 3
        //   [AX] Fallback to synthetic events
        //   → AX failed, fallback to selection
        //   → Shift+Left 1/1
        //   → Sending text chunked: 'ị'
        injector.injectViaAXDirect(backspaceCount: 1, text: "ị")
        
        // ❌ BUG: screen should be "dị" but is "diị"
        XCTAssertNotEqual(screen.text, "dị",
            "With broken selection, screen is NOT 'dị'")
        XCTAssertEqual(screen.text, "diị",
            "Screen is 'diị' — the 'i' was NOT replaced")
        
        // [09:43:20] Engine: insertKey: keyCode=8 'c'
        // Engine: checkMarkPosition → already correct → bs=0, chars=0
        screen.insertCharacter("c")
        XCTAssertEqual(screen.text, "diịc", "After 'c': screen='diịc'")
        
        // [09:43:20] Engine: insertKey: keyCode=4 'h'
        // Engine: checkMarkPosition → already correct → bs=0, chars=0
        screen.insertCharacter("h")
        
        // Final result on screen
        XCTAssertEqual(screen.text, "diịch",
            "🐛 CONFIRMED: User sees 'diịch' instead of 'dịch'")
        
        // Verify the full injection log matches the debug log pattern
        let axFailures = injector.logs.filter { $0 == "[AX] No value attribute" }
        XCTAssertEqual(axFailures.count, 3, "Should show 3 AX failures as in the log")
        
        XCTAssertTrue(injector.logs.contains("[AX] Fallback to synthetic events"))
        XCTAssertTrue(injector.logs.contains("    → AX failed, fallback to selection"))
        XCTAssertTrue(injector.logs.contains("    → Shift+Left 1/1"))
        XCTAssertTrue(injector.logs.contains("injectSync: complete (AX Direct)"))
        
        print("\n=== Log Replay Complete ===")
        print("Expected: dịch")
        print("Actual:   \(screen.text)")
        print("Status:   🐛 BUG CONFIRMED")
    }
}
