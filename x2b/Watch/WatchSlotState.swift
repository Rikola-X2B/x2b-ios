//
//  WatchSlotState.swift
//  x2b
//

import Foundation

/// A single Watch grid slot's precomputed display+action state. Compiled into both
/// the iPhone app target and the Watch app target - the iPhone (which owns the live
/// box connection) fills these in and sends them over WatchConnectivity; the Watch
/// only ever renders what it's told, it never talks to a box directly.
struct WatchSlotState: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let iconName: String
    let isOn: Bool
    let isAssigned: Bool
    let isActionable: Bool
}

/// The full payload pushed to the Watch via `WCSession.updateApplicationContext`.
struct WatchPayload: Codable, Equatable {
    let slots: [WatchSlotState]
    let isConnected: Bool

    static let empty = WatchPayload(slots: [], isConnected: false)
}
