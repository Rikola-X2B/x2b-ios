//
//  CarPlaySlot.swift
//  x2b
//

import Foundation

/// The kind of thing a CarPlay grid slot represents. This is a UI-level category the
/// user picks explicitly - the box's own `X2BControl.type` (e.g. "switch") isn't
/// specific enough to tell a garage door from a light from a generic switch.
enum CarPlaySlotType: String, Codable, CaseIterable, Identifiable {
    case garage
    case light
    case switchGeneric = "switch"
    case valueDisplay
    case sceneArrive
    case sceneLeave

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .garage: return "Garage"
        case .light: return "Licht"
        case .switchGeneric: return "Schalter"
        case .valueDisplay: return "Wertanzeige"
        case .sceneArrive: return "Szene: Ankommen"
        case .sceneLeave: return "Szene: Gehen"
        }
    }

    enum Behavior {
        /// Sends `SetControlValue` with the flipped boolean value on tap.
        case toggle
        /// Sends `SetControlValue` once (momentary), no persistent on/off state.
        case scene
        /// No command is ever sent - just displays the control's current value.
        case readOnly
    }

    var behavior: Behavior {
        switch self {
        case .garage, .light, .switchGeneric: return .toggle
        case .sceneArrive, .sceneLeave: return .scene
        case .valueDisplay: return .readOnly
        }
    }

    func icon(isOn: Bool) -> String {
        switch self {
        case .garage: return isOn ? "door.garage.open" : "door.garage.closed"
        case .light: return isOn ? "lightbulb.fill" : "lightbulb"
        case .switchGeneric: return isOn ? "power.circle.fill" : "power.circle"
        case .valueDisplay: return "gauge"
        case .sceneArrive: return "figure.walk.arrival"
        case .sceneLeave: return "figure.walk.departure"
        }
    }
}

/// One of the (up to 8) CarPlay grid slots for a connection: a UI category plus which
/// real box control - if any yet - is bound to it. `controlName` is cached at
/// assignment time purely for display, so the slot still shows something meaningful
/// when the box isn't reachable to re-fetch its control list.
struct CarPlaySlotAssignment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: CarPlaySlotType
    var controlId: Int?
    var controlName: String?
}

extension CarPlaySlotAssignment {
    /// 8 blank slots, matching CPGridTemplate's maximum button count. The user fills
    /// in type + real control for each via the CarPlay assignment dialog.
    static var defaultSlots: [CarPlaySlotAssignment] {
        (0..<8).map { _ in CarPlaySlotAssignment(type: .switchGeneric, controlId: nil, controlName: nil) }
    }
}
