//
//  AppLanguageTests.swift
//  XKeyTests
//

import XCTest
@testable import XKey

class AppLanguageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure a clean slate — earlier test runs or unrelated code may have left
        // values in the standard domain that would skew assertions.
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        super.tearDown()
    }

    // MARK: - applyLanguage

    func testApplyLanguageVietnamese() {
        UserDefaults.standard.set("vi", forKey: "appLanguage")
        AppLanguage.applyLanguage()
        let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(languages, ["vi"])
    }

    func testApplyLanguageEnglish() {
        UserDefaults.standard.set("en", forKey: "appLanguage")
        AppLanguage.applyLanguage()
        let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(languages, ["en"])
    }

    func testApplyLanguageChinese() {
        UserDefaults.standard.set("zh-Hans", forKey: "appLanguage")
        AppLanguage.applyLanguage()
        let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(languages, ["zh-Hans"])
    }

    // Sentinel locale never present in NSGlobalDomain — lets us detect whether
    // applyLanguage() removed our app-level override even though UserDefaults.standard
    // falls back to NSGlobalDomain for AppleLanguages (so reading nil after removal is
    // not reliable on a real system).
    private static let sentinelOverride = ["xx-XKey-test"]

    func testApplyLanguageSystemClearsAppOverride() {
        UserDefaults.standard.set(Self.sentinelOverride, forKey: "AppleLanguages")
        UserDefaults.standard.set("system", forKey: "appLanguage")

        AppLanguage.applyLanguage()

        // App-level override must be cleared so OS locale takes effect next launch.
        let result = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertNotEqual(result, Self.sentinelOverride)
    }

    func testMissingKeyDefaultsToVietnamese() {
        // No "appLanguage" stored — first-launch user. Should default to Vietnamese,
        // not .system, since XKey is a Vietnamese input method.
        AppLanguage.applyLanguage()

        let result = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(result, ["vi"])
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(AppLanguage(rawValue: "invalid"))
    }

    func testApplyLanguageInvalidValueDefaultsToVietnamese() {
        // Invalid stored value (e.g., corrupted preferences) must fall back to .vi
        // (the default) rather than leaving stale state.
        UserDefaults.standard.set("garbage", forKey: "appLanguage")

        AppLanguage.applyLanguage()

        let result = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(result, ["vi"])
    }

    // MARK: - localeIdentifier

    func testLocaleIdentifiers() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.vi.localeIdentifier, "vi")
        XCTAssertEqual(AppLanguage.en.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.zhHans.localeIdentifier, "zh-Hans")
    }

    // MARK: - Codable backward compatibility

    func testPreferencesDefaultLanguageIsVietnamese() {
        let prefs = Preferences()
        XCTAssertEqual(prefs.appLanguage, .vi)
    }

    func testPreferencesRoundTripWithAppLanguage() throws {
        var prefs = Preferences()
        prefs.appLanguage = .zhHans

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(decoded.appLanguage, .zhHans)
    }
}
