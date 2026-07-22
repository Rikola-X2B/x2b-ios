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
        guard let host = URL(string: baseUrl)?.host else { return nil }
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let matching = cookies.filter { host.hasSuffix($0.domain) || $0.domain.hasSuffix(host) }
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}
