//
//  UpdateChecker.swift
//  LaVieKey
//
//  Self-update straight from GitHub Releases.
//
//  Sparkle ships in the bundle but is deliberately unused: its feed was the
//  upstream project's, its EdDSA key is theirs, and — decisively — Sparkle
//  validates that an update carries the *same* code signature as the running
//  app. LaVieKey is ad-hoc signed (no Apple account by design), so every build
//  has a different signature and Sparkle would reject its own updates. This
//  checker does what install.sh does, from inside the app.
//

import AppKit

struct ReleaseInfo {
    let version: String          // "2.1.0"
    let notes: String
    let downloadURL: URL
    let pageURL: URL
}

enum UpdateCheckResult {
    case upToDate
    case available(ReleaseInfo)
    case failed(String)
}

final class UpdateChecker {

    static let shared = UpdateChecker()

    private let repo = "LaVieNguyenn/LaVieKey"
    private let assetName = "LaVieKey.zip"

    /// Guards against two checks running at once (menu + scheduled timer)
    private var isChecking = false

    private init() {}

    // MARK: - Check

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check(completion: @escaping (UpdateCheckResult) -> Void) {
        guard !isChecking else { return }
        isChecking = true

        let finish: (UpdateCheckResult) -> Void = { [weak self] result in
            self?.isChecking = false
            DispatchQueue.main.async { completion(result) }
        }

        guard let api = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            finish(.failed("URL không hợp lệ")); return
        }

        var request = URLRequest(url: api)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                finish(.failed(error.localizedDescription)); return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                finish(.failed("GitHub trả về mã \(http.statusCode)")); return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String
            else {
                finish(.failed("Không đọc được thông tin bản phát hành")); return
            }

            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let notes = (json["body"] as? String) ?? ""
            let page = (json["html_url"] as? String).flatMap(URL.init(string:))
                ?? URL(string: "https://github.com/\(self.repo)/releases")!

            // Prefer the asset actually attached to this release; fall back to
            // the stable "latest" redirect so a mis-tagged release still works.
            let assets = (json["assets"] as? [[String: Any]]) ?? []
            let assetURL = assets
                .first { ($0["name"] as? String) == self.assetName }
                .flatMap { ($0["browser_download_url"] as? String) }
                .flatMap(URL.init(string:))
                ?? URL(string: "https://github.com/\(self.repo)/releases/latest/download/\(self.assetName)")!

            guard Self.isVersion(latest, newerThan: self.currentVersion) else {
                finish(.upToDate); return
            }
            finish(.available(ReleaseInfo(version: latest, notes: notes, downloadURL: assetURL, pageURL: page)))
        }.resume()
    }

    /// Numeric component-wise comparison ("2.10.0" > "2.9.0", which a string
    /// compare gets wrong). Non-numeric suffixes are ignored.
    static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        for i in 0..<max(l.count, r.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    // MARK: - Download & install

    /// Download the release zip, swap it into place and relaunch.
    /// - Parameter progress: 0…1, called on the main thread.
    func downloadAndInstall(_ release: ReleaseInfo,
                            progress: @escaping (Double) -> Void,
                            failure: @escaping (String) -> Void) {
        let task = URLSession.shared.downloadTask(with: release.downloadURL) { [weak self] tempURL, response, error in
            guard let self else { return }
            let fail: (String) -> Void = { message in
                DispatchQueue.main.async { failure(message) }
            }

            if let error { fail(error.localizedDescription); return }
            guard let tempURL else { fail("Tải về thất bại"); return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                fail("Tải về thất bại (mã \(http.statusCode))"); return
            }

            do {
                try self.installUpdate(zipAt: tempURL)
            } catch {
                fail(error.localizedDescription)
            }
        }

        // Report progress on the main thread; the observation lives as long as
        // the task does.
        let observation = task.progress.observe(\.fractionCompleted) { taskProgress, _ in
            DispatchQueue.main.async { progress(taskProgress.fractionCompleted) }
        }
        progressObservations.append(observation)

        task.resume()
    }

    private var progressObservations: [NSKeyValueObservation] = []

    /// Unpack next to the app, then hand the swap to a detached shell so the
    /// replacement happens *after* this process exits — an app cannot reliably
    /// overwrite itself while running.
    private func installUpdate(zipAt zipURL: URL) throws {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("LaVieKeyUpdate-\(ProcessInfo.processInfo.processIdentifier)")
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        // ditto handles the bundle's symlinks/extended attributes correctly
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zipURL.path, staging.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw NSError(domain: "LaVieKey", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Không giải nén được gói cập nhật"])
        }

        let newApp = staging.appendingPathComponent("LaVieKey.app")
        guard fm.fileExists(atPath: newApp.path) else {
            throw NSError(domain: "LaVieKey", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Gói cập nhật không chứa LaVieKey.app"])
        }

        let currentApp = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier

        // $1 = new app, $2 = installed app. Passed as arguments (not
        // interpolated) so paths with spaces or quotes are safe.
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "$2"
        cp -R "$1" "$2"
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        rm -rf "$(dirname "$1")"
        open "$2"
        """

        let swap = Process()
        swap.executableURL = URL(fileURLWithPath: "/bin/bash")
        swap.arguments = ["-c", script, "--", newApp.path, currentApp.path]
        try swap.run()

        DispatchQueue.main.async {
            // Deliberate: the swap script is already waiting on this PID, so the
            // quit must not be held up by the ⌘Q confirmation.
            if let delegate = AppDelegate.shared {
                delegate.requestQuit(reason: "cài đặt bản cập nhật rồi khởi động lại")
            } else {
                NSApp.terminate(nil)
            }
        }
    }
}
