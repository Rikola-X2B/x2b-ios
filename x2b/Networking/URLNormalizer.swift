//
//  URLNormalizer.swift
//  x2b
//

import Foundation

/// Normalizes user-entered server addresses the same way the Android app does:
/// plain IPv4 addresses (typically local boxes without a valid TLS certificate)
/// get an `http://` prefix, everything else automatically becomes `https://`.
enum URLNormalizer {
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return trimmed
        }

        if isIPv4(trimmed) {
            return "http://\(trimmed)"
        }

        return "https://\(trimmed)"
    }

    /// Strips a trailing slash so it can be safely concatenated with a path.
    static func normalizeBase(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") { url.removeLast() }
        return url
    }

    private static func isIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let n = Int(part) else { return false }
            return n >= 0 && n <= 255
        }
    }
}
