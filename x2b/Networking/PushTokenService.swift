//
//  PushTokenService.swift
//  x2b
//

import Foundation
import WebKit

/// Registers/unregisters this device's push token with the currently active X2B box,
/// mirroring `MainActivity.registerTokenToBox` / `unregisterTokenFromBox` on Android.
///
/// Android posts the FCM token to `{baseUrl}/syspg/push/android`. iOS uses native APNs
/// instead of Firebase (no Firebase project credentials are available in this port), so
/// the raw APNs device token is posted to the analogous `{baseUrl}/syspg/push/ios` path.
/// The box/server side needs a handler for that path that accepts APNs tokens.
enum PushTokenService {
    enum Action: String {
        case register
        case unregister
    }

    static func send(action: Action, baseUrl: String, token: String, serialNumber: String) async {
        let normalized = URLNormalizer.normalizeBase(baseUrl)
        guard let url = URL(string: normalized + "/syspg/push/ios") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        // Session cookies from the WebView are forwarded, same as Android forwards
        // its CookieManager cookies, so the box can authenticate the request.
        if let cookieHeader = await cookieHeader(for: baseUrl), !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        let payload: [String: Any] = [
            "token": token,
            "action": action.rawValue,
            "serialNumber": serialNumber
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        _ = try? await URLSession.shared.data(for: request)
    }

    private static func cookieHeader(for baseUrl: String) async -> String? {
        guard let host = URL(string: baseUrl)?.host else { return nil }
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let matching = cookies.filter { host.hasSuffix($0.domain) || $0.domain.hasSuffix(host) }
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}
