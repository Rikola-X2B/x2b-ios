//
//  CarPlayEntityStore.swift
//  x2b
//

import Foundation
import Combine

/// Bridges the currently displayed connection's `carPlaySlots` assignments to live
/// data from `X2BWebSocketClient`, for both the real CarPlay grid and the
/// phone-side preview - "displayed" so CarPlay follows a "Vorschau" preview too,
/// not just the persisted active connection.
///
/// Multiple consumers (the CarPlay scene and the phone preview) can be interested at
/// the same time, so this is reference-counted via `acquire()`/`release()` rather than
/// connecting/disconnecting per-consumer - only tears down the socket once nobody
/// needs it anymore.
@MainActor
final class CarPlayEntityStore: ObservableObject {
    static let shared = CarPlayEntityStore(slotsKeyPath: \.carPlaySlots)
    /// Same mechanism, but reading the Watch's independent 8-slot layout instead of
    /// CarPlay's - used by `PhoneWatchConnector` to relay to a paired Apple Watch.
    static let sharedForWatch = CarPlayEntityStore(slotsKeyPath: \.watchSlots)

    @Published private(set) var isConnected = false
    @Published private(set) var controls: [Int: X2BControl] = [:]

    private let slotsKeyPath: KeyPath<Connection, [CarPlaySlotAssignment]>
    private let socket = X2BWebSocketClient()
    private var socketSubscription: AnyCancellable?
    private var connectionSubscription: AnyCancellable?
    private var connectedUrl: String?
    private var refCount = 0

    private init(slotsKeyPath: KeyPath<Connection, [CarPlaySlotAssignment]>) {
        self.slotsKeyPath = slotsKeyPath
        // `objectWillChange` fires before the socket's own properties are actually
        // updated, so read them back on the next runloop turn rather than inline.
        socketSubscription = socket.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.syncFromSocket() }
            }
    }

    func acquire() {
        refCount += 1
        if connectionSubscription == nil {
            connectionSubscription = ConnectionStore.shared.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.reconnectIfNeeded()
                        // The active connection's carPlaySlots may have changed (a
                        // new assignment was saved) even without the box itself
                        // changing - let consumers re-render either way.
                        self?.objectWillChange.send()
                    }
                }
        }
        reconnectIfNeeded()
    }

    func release() {
        refCount = max(0, refCount - 1)
        guard refCount == 0 else { return }
        connectionSubscription = nil
        socket.disconnect()
        connectedUrl = nil
        controls = [:]
        isConnected = false
    }

    var slots: [CarPlaySlotAssignment] {
        ConnectionStore.shared.displayedConnection?[keyPath: slotsKeyPath] ?? CarPlaySlotAssignment.defaultSlots
    }

    func control(for slot: CarPlaySlotAssignment) -> X2BControl? {
        guard let id = slot.controlId else { return nil }
        return controls[id]
    }

    func performAction(for slot: CarPlaySlotAssignment) {
        guard let control = control(for: slot), control.alterable else { return }
        switch slot.type.behavior {
        case .toggle:
            socket.setControlValue(id: control.id, value: .bool(!(control.value.boolValue ?? false)))
        case .scene:
            // pushButton controls turn themselves back off after a moment - we only
            // ever need to request "on".
            socket.setControlValue(id: control.id, value: .bool(true))
        case .readOnly:
            break
        }
    }

    private func reconnectIfNeeded() {
        guard let url = ConnectionStore.shared.displayedConnection?.url, url != connectedUrl else { return }
        connectedUrl = url
        socket.disconnect()
        socket.connect(baseUrl: url)
    }

    private func syncFromSocket() {
        isConnected = socket.isConnected
        controls = socket.controls
    }
}
