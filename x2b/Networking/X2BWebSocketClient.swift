//
//  X2BWebSocketClient.swift
//  x2b
//

import Foundation

/// Live connection to a box over the X2BCP WebSocket API at
/// `{ws|wss}://{host}/ws/x2b`.
///
/// On connect: asks for the full control list (`GetControls`) - the protocol has no
/// way to fetch just a handful of ids, so this part always returns everything the
/// box knows about - then, unless told not to via
/// `connect(baseUrl:trackLiveUpdates:registerIds:)`, subscribes to either specific
/// ids or all of them (`RegisterControls`) so the box pushes `ControlValueUpdate`
/// messages whenever something changes. Reconnects with exponential backoff on drop.
@MainActor
final class X2BWebSocketClient: ObservableObject {
    @Published private(set) var controls: [Int: X2BControl] = [:]
    @Published private(set) var isConnected = false

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var sessionDelegate: WebSocketSessionDelegate?
    /// The connection's normalized http(s) base URL (e.g. from `Connection.url`) -
    /// kept as-is rather than split into host/scheme upfront, since the ws/wss
    /// scheme and cookie lookup both need to derive from it.
    private var baseUrl: String?
    private var reconnectAttempt = 0
    private var isStopped = true
    private var generation = 0
    private var trackLiveUpdates = true
    private var registerIds: [Int]?
    private var cookieOverride: [HTTPCookie]?

    /// - Parameters:
    ///   - baseUrl: the box's normalized connection URL, e.g.
    ///     `https://berg.x2.energy` for a hostname or `http://192.168.1.50` for a
    ///     plain IPv4 address (matching `URLNormalizer`). The websocket scheme
    ///     mirrors whichever of http/https was used - local boxes without a valid
    ///     certificate get `ws://`, everything else gets `wss://`.
    ///   - trackLiveUpdates: whether to also register for `ControlValueUpdate` pushes
    ///     after the initial `GetControls` fetch. A caller that only needs the static
    ///     list once (e.g. to populate a picker of control names) should pass
    ///     `false` - registering for every control on a box with a large number of
    ///     them means the box keeps re-sending values that will never be displayed,
    ///     for as long as that connection stays open.
    ///   - registerIds: which control ids to register for when `trackLiveUpdates` is
    ///     true, instead of literally every control the box reports. A caller that
    ///     only ever displays a handful of them (e.g. 8 CarPlay slots) should pass
    ///     those ids explicitly - nil falls back to registering everything, for a
    ///     caller that genuinely needs live tracking of the whole list.
    ///   - cookieOverride: pre-fetched cookies to use instead of looking them up from
    ///     the main app's `WKWebsiteDataStore` - needed by the X2BWidget extension,
    ///     which runs in its own process with no access to that store at all, and so
    ///     gets its cookies relayed from the main app via the shared App Group
    ///     instead (see `WidgetShared`).
    func connect(baseUrl: String, trackLiveUpdates: Bool = true, registerIds: [Int]? = nil, cookieOverride: [HTTPCookie]? = nil) {
        isStopped = false
        self.baseUrl = baseUrl
        self.trackLiveUpdates = trackLiveUpdates
        self.registerIds = registerIds
        self.cookieOverride = cookieOverride
        generation += 1
        reconnectAttempt = 0
        Task { await openAndListen(generation: generation) }
    }

    /// One-shot fetch for a caller that can't stay connected (e.g. a widget's
    /// `TimelineProvider`, which just needs a snapshot) - connects, waits briefly for
    /// `GetControlsResponse` to populate `controls`, then disconnects. Polls rather
    /// than awaiting a proper completion since the rest of this class is
    /// callback/Combine-based, not structured around single awaitable requests.
    func fetchControlsOnce(baseUrl: String, cookieOverride: [HTTPCookie]? = nil, timeout: TimeInterval = 5) async -> [Int: X2BControl] {
        connect(baseUrl: baseUrl, trackLiveUpdates: false, cookieOverride: cookieOverride)
        let deadline = Date().addingTimeInterval(timeout)
        while controls.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        let result = controls
        disconnect()
        return result
    }

    func disconnect() {
        isStopped = true
        generation += 1
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
        sessionDelegate = nil
        isConnected = false
        controls = [:]
    }

    func setControlValue(id: Int, value: X2BControlValue) {
        send(X2BWSSOutgoing.SetControlValue(id: id, value: value))
    }

    private func openAndListen(generation: Int) async {
        guard !isStopped, let baseUrl, let url = webSocketURL(from: baseUrl) else {
            print("🔎 [X2BWS] invalid base URL, not connecting: \(baseUrl ?? "nil")")
            return
        }

        // `webSocketTask(with:protocols:)` is the only initializer that actually
        // negotiates a Sec-WebSocket-Protocol - setting that header manually on a
        // plain URLRequest gets silently dropped (the websocket handshake manages
        // Sec-WebSocket-* headers itself), so the box was never actually being asked
        // for "X2BCP" at all. That means cookies can't ride along on a request header
        // either; they're seeded into the session's own cookie storage instead, which
        // URLSession attaches to matching-domain requests - including this one -
        // automatically.
        let configuration = URLSessionConfiguration.default
        let cookies: [HTTPCookie]
        if let cookieOverride {
            cookies = cookieOverride
        } else {
            cookies = await WebViewCookies.matching(for: baseUrl)
        }
        if !cookies.isEmpty {
            cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
            configuration.httpCookieStorage = .shared
            configuration.httpCookieAcceptPolicy = .always
            print("🔎 [X2BWS] connecting to \(url.absoluteString) with \(cookies.count) cookie(s)")
        } else {
            print("🔎 [X2BWS] connecting to \(url.absoluteString) WITHOUT any cookies (no matching WebView cookie found for host)")
        }

        // A plain delegate is needed (rather than URLSession.shared) so we can see
        // *why* the handshake failed - `receive()` alone only ever reports a generic
        // "socket is not connected" error, with none of the underlying HTTP status or
        // network error that actually explains it.
        let delegate = WebSocketSessionDelegate(
            onOpen: { [weak self] negotiatedProtocol in
                Task { @MainActor in
                    guard let self, generation == self.generation else { return }
                    print("🔎 [X2BWS] handshake succeeded, negotiated protocol: \(negotiatedProtocol ?? "none")")
                    self.isConnected = true
                    self.reconnectAttempt = 0
                }
            },
            onComplete: { [weak self] error, response in
                Task { @MainActor in
                    guard let self, generation == self.generation else { return }
                    let status = (response as? HTTPURLResponse)?.statusCode
                    print("🔎 [X2BWS] socket closed - error: \(error?.localizedDescription ?? "none"), httpStatus: \(status.map(String.init) ?? "n/a")")
                    self.isConnected = false
                    self.scheduleReconnect(generation: generation)
                }
            }
        )
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        sessionDelegate = delegate
        self.session = session

        let newTask = session.webSocketTask(with: url, protocols: ["X2BCP"])
        task = newTask
        newTask.resume()

        send(X2BWSSOutgoing.GetControls())
        listen(on: newTask, generation: generation)
    }

    private func listen(on task: URLSessionWebSocketTask, generation: Int) {
        task.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                // A reconnect may have already started a newer generation while this
                // receive was in flight - don't let a stale one resurrect old state.
                guard generation == self.generation else { return }

                switch result {
                case .success(let message):
                    self.handle(message)
                    self.listen(on: task, generation: generation)
                case .failure(let error):
                    // The session delegate's didCompleteWithError already reports the
                    // real cause and schedules the reconnect - this branch just stops
                    // the receive loop for the dead task.
                    print("🔎 [X2BWS] receive failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Mirrors the base URL's scheme (http -> ws, https -> wss) and carries over its
    /// host/port, e.g. `http://192.168.1.50` -> `ws://192.168.1.50/ws/x2b`.
    private func webSocketURL(from baseUrl: String) -> URL? {
        guard var components = URLComponents(string: baseUrl), components.host != nil else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws/x2b"
        return components.url
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message, let data = text.data(using: .utf8) else { return }
        print("🔎 [X2BWS] received: \(text)")
        guard let decoded = X2BWSSIncoming.decode(data) else {
            print("🔎 [X2BWS] could not decode the message above into any known type")
            return
        }

        switch decoded {
        case .getControlsResponse(let response):
            // Per the API's error rules, ignore any data if an error is present -
            // it may be absent or invalid, not just an empty success.
            guard response.errorCode == nil, let controls = response.controls else {
                print("🔎 [X2BWS] GetControlsResponse had an error or no controls: \(response.errorMessage ?? "nil")")
                return
            }
            apply(controls)
            guard trackLiveUpdates else { return }
            let ids = registerIds ?? controls.map(\.id)
            if !ids.isEmpty {
                send(X2BWSSOutgoing.RegisterControls(ids: ids))
            }
        case .registerControlsResponse(let response):
            guard response.errorCode == nil, let controls = response.controls else {
                print("🔎 [X2BWS] RegisterControlsResponse had an error or no controls: \(response.errorMessage ?? "nil")")
                return
            }
            apply(controls)
        case .controlValueUpdate(let update):
            print("🔎 [X2BWS] ControlValueUpdate for ids \(update.controls.map(\.id)) -> \(update.controls.map(\.value))")
            apply(update.controls)
        case .setControlValueResponse(let response):
            guard response.errorCode == nil, let control = response.control else {
                print("🔎 [X2BWS] SetControlValueResponse had an error or no control: \(response.errorMessage ?? "nil")")
                return
            }
            print("🔎 [X2BWS] SetControlValueResponse for id \(control.id) -> \(control.value)")
            apply([control])
        }
    }

    private func apply(_ updated: [X2BControl]) {
        for control in updated {
            controls[control.id] = control
        }
    }

    private func send<T: Encodable>(_ message: T) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        print("🔎 [X2BWS] sending: \(text)")
        task?.send(.string(text)) { error in
            if let error {
                print("🔎 [X2BWS] send failed: \(error.localizedDescription)")
            }
        }
    }

    private func scheduleReconnect(generation: Int) {
        guard !isStopped else { return }
        reconnectAttempt += 1
        let delaySeconds = min(pow(2.0, Double(reconnectAttempt)), 30)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard generation == self.generation else { return }
            await self.openAndListen(generation: generation)
        }
    }
}

/// Reports what `URLSessionWebSocketTask.receive(completionHandler:)` alone can't:
/// whether the HTTP upgrade handshake actually succeeded, and if not, the real HTTP
/// status/network error behind the failure. Delegate callbacks arrive on the
/// session's own background queue, not the main actor - callers must hop back
/// themselves. The class itself is `@unchecked Sendable` since its only state is two
/// immutable closures assigned once at init, which is safe despite not being
/// provably Sendable to the compiler.
private final class WebSocketSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let onOpen: (String?) -> Void
    private let onComplete: (Error?, URLResponse?) -> Void

    init(onOpen: @escaping (String?) -> Void, onComplete: @escaping (Error?, URLResponse?) -> Void) {
        self.onOpen = onOpen
        self.onComplete = onComplete
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen(`protocol`)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete(error, task.response)
    }
}
