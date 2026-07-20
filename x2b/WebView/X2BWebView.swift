//
//  X2BWebView.swift
//  x2b
//

import SwiftUI
import UIKit
import WebKit

/// Wraps `WKWebView` to show the X2B visualization, mirroring the WebView setup in
/// Android's `MainActivity`: persistent cookies/session, a JS bridge equivalent to
/// `X2BApp.onLoginSuccess()` / `X2BApp.onLogout()`, and a URL-based login/logout
/// heuristic (a URL not containing "login" means we're past the login page).
struct X2BWebView: UIViewRepresentable {
    let url: URL
    var onLoginDetected: () -> Void = {}
    var onLogoutDetected: () -> Void = {}
    var onLoadError: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "X2BApp")
        contentController.addUserScript(Coordinator.bridgeScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black
        // WKWebView's scroll view otherwise reserves space for the notch/status bar on
        // its own, regardless of how we position the WebView in SwiftUI - which showed
        // as a persistent black strip even in edge-to-edge mode. Reserving that space is
        // entirely our (SwiftUI-level) responsibility here, matching Android's manual
        // top-inset-only padding.
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.webView = webView
        context.coordinator.loadedURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            context.coordinator.loginDetected = false
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: X2BWebView
        weak var webView: WKWebView?
        var loadedURL: URL?
        var loginDetected = false
        private var memoryWarningObserver: NSObjectProtocol?
        private var lastMemoryWarningReload: Date?

        static let bridgeScript: WKUserScript = {
            let source = """
            window.X2BApp = {
                onLoginSuccess: function() {
                    window.webkit.messageHandlers.X2BApp.postMessage('loginSuccess');
                },
                onLogout: function() {
                    window.webkit.messageHandlers.X2BApp.postMessage('logout');
                }
            };
            """
            return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        }()

        init(parent: X2BWebView) {
            self.parent = parent
            super.init()

            // Proactively reload on a system memory warning to release the WebContent
            // process's accumulated heap (e.g. from a long-running live dashboard page)
            // before iOS considers the whole app for a jetsam/OOM kill.
            memoryWarningObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reloadAfterMemoryWarning()
            }
        }

        deinit {
            if let memoryWarningObserver {
                NotificationCenter.default.removeObserver(memoryWarningObserver)
            }
        }

        private func reloadAfterMemoryWarning() {
            guard let webView else { return }

            // Guard against a reload-triggers-warning-triggers-reload feedback loop:
            // a reload itself briefly uses memory while the new page spins up, which
            // could otherwise trip another warning almost immediately.
            let minimumInterval: TimeInterval = 30
            if let lastMemoryWarningReload, Date().timeIntervalSince(lastMemoryWarningReload) < minimumInterval {
                return
            }
            lastMemoryWarningReload = Date()

            loginDetected = false
            webView.reload()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "X2BApp", let body = message.body as? String else { return }
            switch body {
            case "loginSuccess":
                handleLoginSuccess()
            case "logout":
                handleLogout()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            let lower = url.absoluteString.lowercased()
            if lower.contains("login") {
                handleLogout()
            } else if !loginDetected {
                handleLoginSuccess()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onLoadError(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onLoadError(error.localizedDescription)
        }

        private func handleLoginSuccess() {
            guard !loginDetected else { return }
            loginDetected = true
            parent.onLoginDetected()
        }

        private func handleLogout() {
            loginDetected = false
            parent.onLogoutDetected()
        }
    }
}
