//
//  WidgetShared.swift
//  x2b
//

import Foundation

/// Shared state between the main app and the X2BWidget extension, via an App Group -
/// a widget extension runs in its own process with no access to the main app's
/// `WKWebsiteDataStore` or in-memory `CarPlayEntityStore`, so this is the only
/// channel between them. The main app (`WidgetBridge`) writes; the widget extension
/// (its `TimelineProvider` and `ToggleControlIntent`) only ever reads.
enum WidgetShared {
    static let appGroupID = "group.energy.inno.x2b"
    static let widgetKind = "X2BWidget"

    private static let defaults = UserDefaults(suiteName: appGroupID)

    private enum Keys {
        static let boxUrl = "widget_box_url"
        static let slots = "widget_slots"
        static let cookies = "widget_cookies"
    }

    /// `HTTPCookie` has no direct `Codable` conformance, and the widget extension has
    /// no `WKWebsiteDataStore` of its own to re-derive them from - so the main app
    /// exports exactly the fields needed to reconstruct equivalent cookies.
    struct SharedCookie: Codable {
        let name: String
        let value: String
        let domain: String
        let path: String
    }

    static func writeBoxUrl(_ url: String?) {
        defaults?.set(url, forKey: Keys.boxUrl)
    }

    static func readBoxUrl() -> String? {
        defaults?.string(forKey: Keys.boxUrl)
    }

    static func writeSlots(_ slots: [CarPlaySlotAssignment]) {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        defaults?.set(data, forKey: Keys.slots)
    }

    static func readSlots() -> [CarPlaySlotAssignment] {
        guard let data = defaults?.data(forKey: Keys.slots),
              let decoded = try? JSONDecoder().decode([CarPlaySlotAssignment].self, from: data) else { return [] }
        return decoded
    }

    static func writeCookies(_ cookies: [SharedCookie]) {
        guard let data = try? JSONEncoder().encode(cookies) else { return }
        defaults?.set(data, forKey: Keys.cookies)
    }

    static func readCookies() -> [HTTPCookie] {
        guard let data = defaults?.data(forKey: Keys.cookies),
              let decoded = try? JSONDecoder().decode([SharedCookie].self, from: data) else { return [] }
        return decoded.compactMap {
            HTTPCookie(properties: [
                .name: $0.name,
                .value: $0.value,
                .domain: $0.domain,
                .path: $0.path,
            ])
        }
    }
}
