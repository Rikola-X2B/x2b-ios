//
//  X2BWebSocketClient.swift
//  x2b
//

import Foundation

/// Live connection to a box over the X2BWSS protocol at `wss://{host}/ws/x2b`.
///
/// On connect: asks for the full control list (`GetControls`), then subscribes to all
/// of them (`RegisterControls`) so the box pushes `ControlStatusUpdate` messages
/// whenever something changes. Reconnects with exponential backoff on drop.
@MainActor
final class X2BWebSocketClient: ObservableObject {
    @Published private(set) var controls: [Int: X2BControl] = [:]
    @Published private(set) var isConnected = false

    private var task: URLSessionWebSocketTask?
    private var host: String?
    private var reconnectAttempt = 0
    private var isStopped = true
    private var generation = 0

    func connect(host: String) {
        isStopped = false
        self.host = host
        generation += 1
        reconnectAttempt = 0
        Task { await openAndListen(generation: generation) }
    }

    func disconnect() {
        isStopped = true
        generation += 1
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
        controls = [:]
    }

    func setControlValue(id: Int, value: X2BControlValue) {
        send(X2BWSSOutgoing.SetControlValue(id: id, value: value))
    }

    private func openAndListen(generation: Int) async {
        guard !isStopped, let host else { return }
        guard let url = URL(string: "wss://\(host)/ws/x2b") else { return }

        var request = URLRequest(url: url)
        request.setValue("X2BWSS", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        if let cookieHeader = await WebViewCookies.header(for: "https://\(host)") {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        let newTask = URLSession.shared.webSocketTask(with: request)
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
                    self.isConnected = true
                    self.reconnectAttempt = 0
                    self.handle(message)
                    self.listen(on: task, generation: generation)
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect(generation: generation)
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message, let data = text.data(using: .utf8) else { return }
        guard let decoded = X2BWSSIncoming.decode(data) else { return }

        switch decoded {
        case .getControlsResponse(let response):
            apply(response.controls)
            let ids = response.controls.map(\.id)
            if !ids.isEmpty {
                send(X2BWSSOutgoing.RegisterControls(ids: ids))
            }
        case .registerControlsResponse(let response):
            apply(response.controls)
        case .controlStatusUpdate(let update):
            apply(update.controls)
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
        task?.send(.string(text)) { _ in }
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
