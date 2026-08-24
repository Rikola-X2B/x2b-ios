//
//  ConnectionStore.swift
//  x2b
//

import Foundation
import Combine

/// Persists X2B box connections and the active/selected one, mirroring the
/// `x2b_connections` SharedPreferences file used by the Android app.
final class ConnectionStore: ObservableObject {
    static let shared = ConnectionStore()

    /// No longer seeded automatically - kept only to clean up any copy left over
    /// from before on existing installs.
    private static let legacyDemoURL = "https://demo.x2.energy"

    @Published private(set) var connections: [Connection] = []
    @Published private(set) var activeConnectionUrl: String = ""

    /// Non-nil while "Vorschau" (the eye button in Settings) is showing a connection
    /// other than the active one. Lives here rather than as view-local state so
    /// CarPlay - which has no view of its own to read it from - can still follow
    /// whatever box the phone screen is actually displaying.
    @Published var previewConnectionUrl: String?

    /// Whether the visualization is shown edge-to-edge or with a reserved status-bar area.
    @Published var edgeToEdge: Bool {
        didSet { defaults.set(edgeToEdge, forKey: Keys.edgeToEdge) }
    }

    /// Whether `LocationSwitchManager` should auto-switch the active connection based
    /// on which box's saved location the phone is currently inside. Toggled via the
    /// GPS icon in Settings.
    @Published var locationSwitchingEnabled: Bool {
        didSet { defaults.set(locationSwitchingEnabled, forKey: Keys.locationSwitchingEnabled) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let connections = "connections"
        static let activeConnectionUrl = "active_connection_url"
        static let edgeToEdge = "visu_edge_to_edge"
        static let locationSwitchingEnabled = "location_switching_enabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.edgeToEdge = defaults.object(forKey: Keys.edgeToEdge) as? Bool ?? false
        self.locationSwitchingEnabled = defaults.object(forKey: Keys.locationSwitchingEnabled) as? Bool ?? false
        self.activeConnectionUrl = defaults.string(forKey: Keys.activeConnectionUrl) ?? ""
        load()
    }

    /// Reloads connections from storage.
    func load() {
        var loaded: [Connection] = []
        if let data = defaults.data(forKey: Keys.connections),
           let decoded = try? JSONDecoder().decode([Connection].self, from: data) {
            loaded = decoded
        }

        // The demo connection used to be seeded automatically on first launch - drop
        // any leftover copy so existing installs don't have to delete it by hand.
        loaded.removeAll { $0.url == Self.legacyDemoURL }

        connections = loaded
        persist()

        // Also covers the active connection having been the just-removed demo entry,
        // or any other connection that's no longer present (e.g. deleted) - in every
        // case, fall back to whatever is first rather than pointing at nothing.
        if !connections.contains(where: { $0.url == activeConnectionUrl }), let first = connections.first {
            setActive(url: first.url)
        }
    }

    func add(_ connection: Connection) {
        connections.append(connection)
        persist()
        DebugLog.log("💾 [Connections] added \"\(connection.name)\" (\(connection.id)), total=\(connections.count)")
    }

    func update(_ connection: Connection) {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else {
            DebugLog.log("💾 [Connections] update FAILED - no connection with id \(connection.id) in store (have: \(connections.map(\.id)))")
            return
        }
        connections[index] = connection
        persist()
        DebugLog.log("💾 [Connections] updated \"\(connection.name)\" (\(connection.id)) at index \(index)")
    }

    func delete(ids: Set<UUID>) {
        connections.removeAll { ids.contains($0.id) }
        persist()
    }

    func setActive(url: String) {
        activeConnectionUrl = url
        defaults.set(url, forKey: Keys.activeConnectionUrl)
    }

    var activeConnection: Connection? {
        connections.first(where: { $0.url == activeConnectionUrl }) ?? connections.first
    }

    /// The connection actually shown on screen right now - the previewed one while a
    /// preview is active, otherwise the active one. CarPlay follows this rather than
    /// `activeConnection` so it always matches what the phone is currently displaying.
    var displayedConnection: Connection? {
        if let previewConnectionUrl, let previewed = connections.first(where: { $0.url == previewConnectionUrl }) {
            return previewed
        }
        return activeConnection
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(connections) {
            defaults.set(data, forKey: Keys.connections)
        }
    }
}
