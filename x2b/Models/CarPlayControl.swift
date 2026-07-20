//
//  CarPlayControl.swift
//  x2b
//

import Foundation

/// A single controllable/triggerable item shown on the CarPlay dashboard.
///
/// This is the local, hardcoded stand-in for what will eventually come from the
/// `/api/v1/entities` server endpoint (see the CarPlay proposal) - a `toggle` maps to
/// the `switch` entity type there, a `scene` has no persistent state, it just fires a
/// command once.
struct CarPlayControl: Identifiable {
    enum Kind {
        case toggle
        case scene
    }

    let id: String
    let name: String
    let icon: String
    let kind: Kind
}

extension CarPlayControl {
    /// The 8 controls for this simulation, standing in for the real entity list until
    /// the box exposes one.
    static let simulationSet: [CarPlayControl] = [
        CarPlayControl(id: "garagentor", name: "Garagentor", icon: "door.garage.closed", kind: .toggle),
        CarPlayControl(id: "haustuer", name: "Haustür", icon: "door.left.hand.closed", kind: .toggle),
        CarPlayControl(id: "anbaugarage", name: "Anbaugarage", icon: "door.garage.closed", kind: .toggle),
        CarPlayControl(id: "licht_garage", name: "Licht Garage", icon: "lightbulb.fill", kind: .toggle),
        CarPlayControl(id: "licht_hebebuehne", name: "Licht Hebebühne", icon: "lightbulb.fill", kind: .toggle),
        CarPlayControl(id: "licht_anbaugarage", name: "Licht Anbaugarage", icon: "lightbulb.fill", kind: .toggle),
        CarPlayControl(id: "szene_ankommen", name: "Ankommen", icon: "figure.walk.arrival", kind: .scene),
        CarPlayControl(id: "szene_gehen", name: "Gehen", icon: "figure.walk.departure", kind: .scene)
    ]
}
