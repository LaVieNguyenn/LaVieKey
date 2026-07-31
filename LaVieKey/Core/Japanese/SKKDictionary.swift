//
//  SKKDictionary.swift
//  LaVieKey
//
//  Kana → kanji lookup backed by SKK-JISYO.L.
//
//  The dictionary is downloaded at runtime rather than bundled: SKK-JISYO is
//  GPL and LaVieKey ships under MIT. This mirrors what VNDictionaryManager
//  already does for the Vietnamese hunspell dictionary.
//
//  File format (EUC-JP), one entry per line:
//      よみ /候補1/候補2;annotation/
//  Entries whose reading ends in a latin letter are okurigana entries
//  (おくr /送/) — skipped in phase 2, which only converts plain readings.
//

import Foundation

final class SKKDictionary {

    static let shared = SKKDictionary()

    /// reading → candidates, in dictionary order (most common first)
    private var entries: [String: [String]] = [:]

    private let queue = DispatchQueue(label: "com.laviekey.skkdict", qos: .utility)
    private(set) var isLoaded = false
    private(set) var isDownloading = false

    /// Reports progress/errors (wired to the debug window)
    var logCallback: ((String) -> Void)?

    private let sourceURL = URL(string: "https://raw.githubusercontent.com/skk-dev/dict/master/SKK-JISYO.L")!

    private init() {}

    // MARK: - Storage

    /// Kept in the App Group container next to the Vietnamese dictionaries so
    /// both processes can reach it and it survives app updates.
    private var dictionaryURL: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: kLaVieKeyAppGroup) else { return nil }
        let dir = container.appendingPathComponent("Dictionaries/ja", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("SKK-JISYO.L.utf8")
    }

    var isDownloaded: Bool {
        guard let url = dictionaryURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var entryCount: Int { entries.count }

    // MARK: - Loading

    /// Load from disk if present. Safe to call repeatedly; does nothing when
    /// already loaded or when the file has not been downloaded yet.
    func loadIfNeeded(completion: ((Bool) -> Void)? = nil) {
        guard !isLoaded else { completion?(true); return }
        guard let url = dictionaryURL, FileManager.default.fileExists(atPath: url.path) else {
            completion?(false); return
        }

        queue.async { [weak self] in
            guard let self else { return }
            let start = Date()
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.logCallback?("Không đọc được từ điển tiếng Nhật")
                    completion?(false)
                }
                return
            }
            let parsed = Self.parse(text)
            DispatchQueue.main.async {
                self.entries = parsed
                self.isLoaded = true
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                self.logCallback?("Từ điển tiếng Nhật: \(parsed.count) mục (\(ms)ms)")
                completion?(true)
            }
        }
    }

    /// Download SKK-JISYO.L, transcode EUC-JP → UTF-8, store and load it.
    func download(progress: ((Double) -> Void)? = nil, completion: @escaping (Bool, String?) -> Void) {
        guard !isDownloading else { completion(false, "Đang tải rồi"); return }
        guard let destination = dictionaryURL else {
            completion(false, "Không truy cập được thư mục dữ liệu"); return
        }
        isDownloading = true

        let task = URLSession.shared.dataTask(with: sourceURL) { [weak self] data, response, error in
            guard let self else { return }
            let finish: (Bool, String?) -> Void = { ok, message in
                self.isDownloading = false
                DispatchQueue.main.async { completion(ok, message) }
            }

            if let error { finish(false, error.localizedDescription); return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                finish(false, "Máy chủ trả về mã \(http.statusCode)"); return
            }
            guard let data else { finish(false, "Không nhận được dữ liệu"); return }

            // SKK dictionaries are EUC-JP; convert once at download time so the
            // hot path only ever reads UTF-8.
            guard let text = String(data: data, encoding: .japaneseEUC)
                    ?? String(data: data, encoding: .utf8) else {
                finish(false, "Không giải mã được từ điển (EUC-JP)"); return
            }

            do {
                try text.write(to: destination, atomically: true, encoding: .utf8)
            } catch {
                finish(false, error.localizedDescription); return
            }

            let parsed = Self.parse(text)
            DispatchQueue.main.async {
                self.entries = parsed
                self.isLoaded = true
                self.logCallback?("Đã tải từ điển tiếng Nhật: \(parsed.count) mục")
            }
            finish(true, nil)
        }

        if let progress {
            let observation = task.progress.observe(\.fractionCompleted) { p, _ in
                DispatchQueue.main.async { progress(p.fractionCompleted) }
            }
            progressObservations.append(observation)
        }
        task.resume()
    }

    private var progressObservations: [NSKeyValueObservation] = []

    /// Free the parsed table (called when Japanese input is switched off)
    func unload() {
        entries.removeAll(keepingCapacity: false)
        isLoaded = false
    }

    // MARK: - Lookup

    /// Candidates for a plain kana reading, best first.
    func candidates(for reading: String) -> [String] {
        guard !reading.isEmpty else { return [] }
        return entries[reading] ?? []
    }

    /// Whether any entry starts with this reading — used to decide if a longer
    /// reading is still worth waiting for.
    func hasEntries(startingWith prefix: String) -> Bool {
        entries.keys.contains { $0.hasPrefix(prefix) }
    }

    // MARK: - Parsing

    /// Parse the SKK text format. Okurigana entries (reading ending in an
    /// ASCII letter) are skipped: converting them needs verb-stem handling,
    /// which is out of scope for phase 2.
    static func parse(_ text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        result.reserveCapacity(140_000)

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard !line.hasPrefix(";;") else { continue }
            guard let space = line.firstIndex(of: " ") else { continue }

            let reading = String(line[line.startIndex..<space])
            guard let last = reading.unicodeScalars.last, !last.isASCII else { continue }

            let body = line[line.index(after: space)...]
            let candidates = body
                .split(separator: "/", omittingEmptySubsequences: true)
                .map { field -> String in
                    // Strip the ";annotation" suffix SKK uses for glosses
                    if let semi = field.firstIndex(of: ";") {
                        return String(field[field.startIndex..<semi])
                    }
                    return String(field)
                }
                .filter { !$0.isEmpty }

            if !candidates.isEmpty {
                result[reading] = candidates
            }
        }
        return result
    }
}
