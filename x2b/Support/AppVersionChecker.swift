//
//  AppVersionChecker.swift
//  x2b
//

import Foundation

/// Checks the App Store for a newer released version, the iOS analog of Android's
/// Play Core "immediate" forced-update flow (`MainActivity.checkForForcedUpdate`).
/// iOS has no OS-level forced-update API, so callers pair this with a blocking
/// screen (`ForcedUpdateView`) instead.
enum AppVersionChecker {
    struct UpdateInfo {
        let storeURL: URL
    }

    static func checkForUpdate(bundleId: String = Bundle.main.bundleIdentifier ?? "") async -> UpdateInfo? {
        guard !bundleId.isEmpty,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let storeVersion = first["version"] as? String,
                  let trackViewUrl = first["trackViewUrl"] as? String,
                  let storeURL = URL(string: trackViewUrl) else {
                return nil
            }

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            guard isVersion(storeVersion, newerThan: currentVersion) else { return nil }
            return UpdateInfo(storeURL: storeURL)
        } catch {
            // Lookup unavailable (offline, throttled, not yet published) - never block the app for this.
            return nil
        }
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhsParts.count, rhsParts.count)
        for index in 0..<count {
            let l = index < lhsParts.count ? lhsParts[index] : 0
            let r = index < rhsParts.count ? rhsParts[index] : 0
            if l != r { return l > r }
        }
        return false
    }
}
