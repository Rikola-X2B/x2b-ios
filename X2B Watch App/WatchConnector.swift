//
//  WatchConnector.swift
//  X2B Watch App
//

import Foundation
import WatchConnectivity

/// The Watch side of the phone<->watch relay: has no network stack of its own, just
/// renders whatever `WatchSlotState` list the phone's `PhoneWatchConnector` last
/// pushed, and forwards taps back to it to actually act on the box.
@MainActor
final class WatchConnector: NSObject, ObservableObject {
    static let shared = WatchConnector()

    @Published private(set) var payload = WatchPayload.empty

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func perform(_ slot: WatchSlotState) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        // Best-effort, no reply handling - if the phone is unreachable right now
        // there's nothing more useful to do than wait for the next context update.
        WCSession.default.sendMessage(["slotId": slot.id.uuidString], replyHandler: nil) { _ in }
    }

    fileprivate func apply(_ context: [String: Any]) {
        guard let data = context["payload"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        payload = decoded
    }
}

extension WatchConnector: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Catches up on a context that was delivered while this app wasn't running -
        // didReceiveApplicationContext below only fires for updates while it is.
        Task { @MainActor in self.apply(session.receivedApplicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}
