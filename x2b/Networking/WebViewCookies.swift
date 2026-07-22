//
//  WebViewCookies.swift
//  x2b
//

import Foundation
import WebKit

/// Forwards the WKWebView's session cookies to plain URLSession/WebSocket requests,
/// so the box can authenticate them the same way it authenticates the logged-in
/// WebView - shared by `PushTokenService` and `X2BWebSocketClient`.
enum WebViewCookies {
    static func header(for baseUrl: String) async -> String? {
        let matching = await matching(for: baseUrl)
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    /// As `HTTPCookie` values rather than a pre-joined header string - needed to seed
    /// a `URLSessionConfiguration`'s cookie storage for `X2BWebSocketClient`, since a
    /// websocket task created from a bare URL (required to also pass `protocols:`)
    /// has no `URLRequest` to attach a manual `Cookie` header to.
    static func matching(for baseUrl: String) async -> [HTTPCookie] {
        guard let host = URL(string: baseUrl)?.host else { return [] }
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return cookies.filter { host.hasSuffix($0.domain) || $0.domain.hasSuffix(host) }
    }
}
