//
//  DebugLog.swift
//  x2b
//

import Foundation

/// Persists debug output to a file on disk (capped in size), in addition to printing
/// it - so diagnostics from things like background geofencing (which can't be
/// watched live from a plugged-in Xcode console, since the whole point is testing
/// while away from a computer) can be reviewed afterwards by sharing the file via
/// the share sheet instead.
enum DebugLog {
    private static let maxBytes = 200_000

    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("debug.log")
    }()

    static func log(_ message: String) {
        print(message)

        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: fileURL)
        }

        trimIfNeeded()
    }

    /// Cheap, approximate trim (keep roughly the second half) rather than exact line
    /// counting - this only needs to stop the file from growing unbounded, not be
    /// precise about it.
    private static func trimIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int, size > maxBytes,
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        try? String(content.suffix(maxBytes / 2)).write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
