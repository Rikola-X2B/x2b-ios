//
//  Color+Hex.swift
//  x2b
//

import SwiftUI

extension Color {
    /// Initializes from a `"RRGGBB"` or `"#RRGGBB"` hex string, used to keep the
    /// exact color values from the Android layouts (e.g. `#2A2A2A`) in one place.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }

        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
