//
//  BoxSettingsView.swift
//  x2b
//

import SwiftUI

/// Entry point for all per-box, control-related settings (CarPlay, Watch, Geofence) -
/// opened via the settings icon on a connection row. Owns a single connection to the
/// box, established once here, so all three destinations already have the control
/// list loaded by the time the user taps into them instead of each reconnecting on
/// its own.
struct BoxSettingsView: View {
    var onSave: (Connection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var connection: Connection
    @StateObject private var client = X2BWebSocketClient()

    init(connection: Connection, onSave: @escaping (Connection) -> Void) {
        self.onSave = onSave
        _connection = State(initialValue: connection)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(client.isConnected ? Color(hex: "4CAF50") : Color(hex: "888888"))
                            .frame(width: 8, height: 8)
                        Text(client.isConnected ? "Box verbunden" : "Verbinde mit Box…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    NavigationLink {
                        CarPlaySlotsAssignmentView(connection: connection, client: client) { updated in
                            connection = updated
                            onSave(updated)
                        }
                    } label: {
                        Label("CarPlay", systemImage: "car.fill")
                    }

                    NavigationLink {
                        WatchSlotsAssignmentView(connection: connection, client: client) { updated in
                            connection = updated
                            onSave(updated)
                        }
                    } label: {
                        Label("Apple Watch", systemImage: "applewatch")
                    }

                    NavigationLink {
                        ConnectionLocationView(connection: connection, client: client) { updated in
                            connection = updated
                            onSave(updated)
                        }
                    } label: {
                        Label("Geofence", systemImage: "mappin.and.ellipse")
                    }
                }
            }
            .navigationTitle(connection.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        // Only need the static list of names to pick from in any of the three
        // destinations, not live values - registering for updates on every one of
        // the box's controls would just mean it keeps re-sending values none of them
        // display, for as long as this screen is open.
        .onAppear { client.connect(baseUrl: connection.url, trackLiveUpdates: false) }
        .onDisappear { client.disconnect() }
    }
}
