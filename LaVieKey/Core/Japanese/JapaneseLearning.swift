//
//  JapaneseLearning.swift
//  LaVieKey
//
//  Phase 3: remember which candidate the user actually picks for a reading,
//  and float it to the top next time. SKK dictionary order is a decent prior
//  but says nothing about *this* user — かんじ offers 漢字 first, yet someone
//  organising events wants 幹事.
//
//  Stored in the App Group container so it survives app updates.
//

import Foundation

final class JapaneseLearning {

    static let shared = JapaneseLearning()

    /// reading → candidates most recently chosen, newest first (max 3 kept)
    private var preferred: [String: [String]] = [:]

    /// Custom entries the user added themselves: reading → candidates
    private var userEntries: [String: [String]] = [:]

    private let maxRemembered = 3
    private var isDirty = false
    private let queue = DispatchQueue(label: "com.laviekey.jplearning", qos: .utility)

    private init() {
        load()
    }

    // MARK: - Storage

    private var storeURL: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: kLaVieKeyAppGroup) else { return nil }
        let dir = container.appendingPathComponent("Dictionaries/ja", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("learning.json")
    }

    private struct Store: Codable {
        var preferred: [String: [String]]
        var userEntries: [String: [String]]
    }

    private func load() {
        guard let url = storeURL,
              let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(Store.self, from: data) else { return }
        preferred = store.preferred
        userEntries = store.userEntries
    }

    /// Persist off the typing thread; called after each pick.
    private func scheduleSave() {
        guard !isDirty else { return }
        isDirty = true
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.isDirty = false
            guard let url = self.storeURL else { return }
            let store = Store(preferred: self.preferred, userEntries: self.userEntries)
            if let data = try? JSONEncoder().encode(store) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    // MARK: - Learning

    /// Record that `candidate` was chosen for `reading`.
    func record(reading: String, candidate: String) {
        guard !reading.isEmpty, !candidate.isEmpty else { return }
        var list = preferred[reading] ?? []
        list.removeAll { $0 == candidate }
        list.insert(candidate, at: 0)
        if list.count > maxRemembered { list.removeLast(list.count - maxRemembered) }
        preferred[reading] = list
        scheduleSave()
    }

    /// Reorder dictionary candidates so previously picked ones come first,
    /// and prepend any user-defined entries.
    func rank(_ candidates: [String], for reading: String) -> [String] {
        let userDefined = userEntries[reading] ?? []
        let remembered = preferred[reading] ?? []

        var result: [String] = []
        var seen = Set<String>()
        for word in userDefined + remembered where !seen.contains(word) {
            result.append(word)
            seen.insert(word)
        }
        for word in candidates where !seen.contains(word) {
            result.append(word)
            seen.insert(word)
        }
        return result
    }

    // MARK: - User dictionary

    var userEntryCount: Int { userEntries.count }

    func addUserEntry(reading: String, candidate: String) {
        let reading = reading.trimmingCharacters(in: .whitespaces)
        let candidate = candidate.trimmingCharacters(in: .whitespaces)
        guard !reading.isEmpty, !candidate.isEmpty else { return }
        var list = userEntries[reading] ?? []
        if !list.contains(candidate) { list.insert(candidate, at: 0) }
        userEntries[reading] = list
        scheduleSave()
    }

    func removeUserEntry(reading: String) {
        userEntries.removeValue(forKey: reading)
        scheduleSave()
    }

    func allUserEntries() -> [(reading: String, candidates: [String])] {
        userEntries.map { ($0.key, $0.value) }.sorted { $0.reading < $1.reading }
    }

    /// Forget everything learned (user dictionary is kept)
    func resetLearned() {
        preferred.removeAll()
        scheduleSave()
    }
}
