//
//  CarPlayControl.swift
//  x2b
//

import Foundation

/// A single controllable/triggerable item shown on the CarPlay dashboard and its
/// phone-side mockup.
///
/// This is the local, hardcoded stand-in for what will eventually come from the
/// `/api/v1/entities` server endpoint (see the CarPlay proposal) - `.toggle` maps to
/// the `switch` entity type there, `.scene` has no persistent state, it just fires a
/// command once. `.toggle` carries both icon variants since CarPlay grid buttons have
/// no built-in on/off chrome - the icon itself has to communicate the state.
struct CarPlayControl: Identifiable {
    enum Kind {
        case toggle(iconOff: String, iconOn: String)
        case scene(icon: String)
    }

    let id: String
    let name: String
    let kind: Kind

    func icon(isOn: Bool) -> String {
        switch kind {
        case .toggle(let iconOff, let iconOn):
            return isOn ? iconOn : iconOff
        case .scene(let icon):
            return icon
        }
    }

    var isToggle: Bool {
        switch kind {
        case .toggle: return true
        case .scene: return false
        }
    }
}

extension CarPlayControl {
    /// The 8 controls for this simulation, standing in for the real entity list until
    /// the box exposes one.
    static let simulationSet: [CarPlayControl] = [
        CarPlayControl(id: "garagentor", name: "Garagentor", kind: .toggle(iconOff: "door.garage.closed", iconOn: "door.garage.open")),
        CarPlayControl(id: "haustuer", name: "Haustür", kind: .toggle(iconOff: "door.left.hand.closed", iconOn: "door.left.hand.open")),
        CarPlayControl(id: "anbaugarage", name: "Anbaugarage", kind: .toggle(iconOff: "door.garage.closed", iconOn: "door.garage.open")),
        CarPlayControl(id: "licht_garage", name: "Licht Garage", kind: .toggle(iconOff: "lightbulb", iconOn: "lightbulb.fill")),
        CarPlayControl(id: "licht_hebebuehne", name: "Licht Hebebühne", kind: .toggle(iconOff: "lightbulb", iconOn: "lightbulb.fill")),
        CarPlayControl(id: "licht_anbaugarage", name: "Licht Anbaugarage", kind: .toggle(iconOff: "lightbulb", iconOn: "lightbulb.fill")),
        CarPlayControl(id: "szene_ankommen", name: "Ankommen", kind: .scene(icon: "figure.walk.arrival")),
        CarPlayControl(id: "szene_gehen", name: "Gehen", kind: .scene(icon: "figure.walk.departure"))
    ]
}
