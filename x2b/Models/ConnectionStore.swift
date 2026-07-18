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

    static let demoURL = "https://demo.x2.energy"

    @Published private(set) var connections: [Connection] = []
    @Published private(set) var activeConnectionUrl: String = ""

    /// Whether the visualization is shown edge-to-edge or with a reserved status-bar area.
    @Published var edgeToEdge: Bool {
        didSet { defaults.set(edgeToEdge, forKey: Keys.edgeToEdge) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let connections = "connections"
        static let activeConnectionUrl = "active_connection_url"
        static let edgeToEdge = "visu_edge_to_edge"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.edgeToEdge = defaults.object(forKey: Keys.edgeToEdge) as? Bool ?? true
        self.activeConnectionUrl = defaults.string(forKey: Keys.activeConnectionUrl) ?? ""
        load()
    }

    /// Reloads connections from storage, seeding the built-in demo connection if missing.
    func load() {
        var loaded: [Connection] = []
        if let data = defaults.data(forKey: Keys.connections),
           let decoded = try? JSONDecoder().decode([Connection].self, from: data) {
            loaded = decoded
        }

        if !loaded.contains(where: { $0.url.contains("demo.x2.energy") }) {
            loaded.insert(Connection(name: "demo", url: Self.demoURL), at: 0)
        }

        connections = loaded
        persist()

        if activeConnectionUrl.isEmpty, let first = connections.first {
            setActive(url: first.url)
        }
    }

    func add(_ connection: Connection) {
        connections.append(connection)
        persist()
    }

    func update(_ connection: Connection) {
        guard let index = connections.firstIndex(where: { $0.id == connection.id }) else { return }
        connections[index] = connection
        persist()
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

    private func persist() {
        if let data = try? JSONEncoder().encode(connections) {
            defaults.set(data, forKey: Keys.connections)
        }
    }
}
