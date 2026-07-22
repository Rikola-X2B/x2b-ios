//
//  CarPlaySimulationStore.swift
//  x2b
//

import Foundation

/// Holds the local, in-memory state for the CarPlay simulation - no network calls,
/// nothing persisted. Once the box exposes the real `/api/v1` endpoints, this is what
/// gets replaced by an `EntityStore` talking to the server instead.
@MainActor
final class CarPlaySimulationStore: ObservableObject {
    /// Shared between the phone-side mockup and the real CarPlay grid scene, so
    /// toggling a control in one place is reflected in the other.
    static let shared = CarPlaySimulationStore()

    @Published private(set) var onStates: [String: Bool] = [:]
    @Published private(set) var recentlyFired: Set<String> = []

    /// Simulated box connection status - no real reachability check against the box
    /// yet, since `/api/v1.1` doesn't exist there yet. Tappable in both the CarPlay
    /// nav bar and the phone mockup so the visual states can be tried out.
    @Published var isConnected: Bool = true

    func toggleConnection() {
        isConnected.toggle()
    }

    func isOn(_ control: CarPlayControl) -> Bool {
        onStates[control.id] ?? false
    }

    func toggle(_ control: CarPlayControl) {
        onStates[control.id] = !isOn(control)
    }

    func fireScene(_ control: CarPlayControl) {
        recentlyFired.insert(control.id)
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            recentlyFired.remove(control.id)
        }
    }
}
