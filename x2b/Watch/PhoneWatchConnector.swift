//
//  PhoneWatchConnector.swift
//  x2b
//

import Foundation
import WatchConnectivity
import Combine

/// Relays the currently displayed connection's Watch-assigned slots to a paired
/// Apple Watch over WatchConnectivity. The Watch has no network stack of its own
/// here - every command it sends comes back through the phone's existing
/// `X2BWebSocketClient` connection via `CarPlayEntityStore.sharedForWatch`, the same
/// way the CarPlay grid and its phone preview share `CarPlayEntityStore.shared`.
@MainActor
final class PhoneWatchConnector: NSObject, ObservableObject {
    static let shared = PhoneWatchConnector()

    private let store = CarPlayEntityStore.sharedForWatch
    private var storeSubscription: AnyCancellable?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        store.acquire()
        // The store changes for lots of reasons (box pushes an update, connection
        // status flips, slot assignment gets edited in Settings) - push a fresh
        // context to the Watch on all of them. `objectWillChange` fires before the
        // store's own properties are updated, so defer the actual re-read.
        storeSubscription = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.pushContext() }
            }
    }

    private func pushContext() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        let slots = store.slots.map { slot -> WatchSlotState in
            let control = store.control(for: slot)
            let isOn = control?.value.boolValue ?? false
            return WatchSlotState(
                id: slot.id,
                title: control?.name ?? slot.controlName ?? slot.type.displayName,
                iconName: slot.type.icon(isOn: isOn),
                isOn: isOn,
                isAssigned: control != nil,
                isActionable: (control?.alterable ?? false) && slot.type.behavior != .readOnly
            )
        }
        let payload = WatchPayload(slots: slots, isConnected: store.isConnected)
        guard let data = try? JSONEncoder().encode(payload) else { return }

        // `updateApplicationContext` (rather than `sendMessage`) since this should
        // reflect "the latest known state" even if the Watch app isn't in the
        // foreground right now - it replaces any previously queued context instead
        // of piling up a backlog of stale updates.
        try? WCSession.default.updateApplicationContext(["payload": data])
    }
}

extension PhoneWatchConnector: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.pushContext() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// The Watch asks to perform a slot's action and waits for a reply, rather than
    /// firing a one-way message, so it can show immediate feedback instead of
    /// guessing whether the tap actually reached the box.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            guard let slotIdString = message["slotId"] as? String,
                  let slotId = UUID(uuidString: slotIdString),
                  let slot = self.store.slots.first(where: { $0.id == slotId }) else {
                replyHandler(["ok": false])
                return
            }
            self.store.performAction(for: slot)
            replyHandler(["ok": true])
        }
    }
}
