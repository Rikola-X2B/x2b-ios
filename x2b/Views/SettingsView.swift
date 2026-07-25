//
//  SettingsView.swift
//  x2b
//

import SwiftUI
import UIKit

/// Connection manager, mirroring `activity_settings.xml` / `SettingsActivity`:
/// a multi-select list of boxes with delete/edit/set-active actions, a per-row
/// preview button, an edge-to-edge/status-bar display toggle, and an add button.
struct SettingsView: View {
    @ObservedObject var connectionStore: ConnectionStore
    @ObservedObject private var locationManager = LocationSwitchManager.shared
    var onPreview: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var editingTarget: EditTarget?
    @State private var showCarPlayPreview = false
    @State private var configuringConnection: Connection?

    private enum EditTarget: Identifiable {
        case add
        case edit(Connection)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let connection): return connection.id.uuidString
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if connectionStore.locationSwitchingEnabled && locationManager.authorizationStatus != .authorizedAlways {
                locationPermissionWarning
            }
            actionBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            ZStack(alignment: .bottomTrailing) {
                connectionList

                Button {
                    editingTarget = .add
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(hex: "FFA726"))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(16)
            }

            bottomBar
        }
        .background(Color(hex: "121212").ignoresSafeArea())
        .sheet(item: $editingTarget) { target in
            NavigationStack {
                switch target {
                case .add:
                    ConnectionEditView(existing: nil) { connectionStore.add($0) }
                case .edit(let connection):
                    ConnectionEditView(existing: connection) { connectionStore.update($0) }
                }
            }
        }
        .fullScreenCover(isPresented: $showCarPlayPreview) {
            CarPlayPreviewView()
        }
        .sheet(item: $configuringConnection) { connection in
            BoxSettingsView(connection: connection) { connectionStore.update($0) }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            Text("Einstellungen")
                .font(.title2.bold())
                .foregroundColor(.white)
            Spacer()
            Button(action: toggleLocationSwitching) {
                Image(systemName: connectionStore.locationSwitchingEnabled ? "location.fill" : "location.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(connectionStore.locationSwitchingEnabled ? Color(hex: "4CAF50") : .white)
                    .frame(width: 48, height: 48)
            }
            Button(action: { showCarPlayPreview = true }) {
                Image(systemName: "car.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            // Only once something has actually been logged - no point offering to
            // share an empty/nonexistent file. Lets debug output (e.g. geofencing,
            // which by nature needs testing away from a plugged-in Xcode console) be
            // sent afterwards via Mail/Nachrichten/AirDrop instead.
            if FileManager.default.fileExists(atPath: DebugLog.fileURL.path) {
                ShareLink(item: DebugLog.fileURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(Color.black)
    }

    /// iOS's automatic "Nur bei Nutzung" -> "Immer" upgrade prompt isn't reliable -
    /// without "Immer", geofencing only fires while the app is open, not while
    /// backgrounded or the phone is locked, so this points the user at Settings
    /// directly rather than leaving them to wonder why switching silently stops.
    private var locationPermissionWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "FFA726"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Standortberechtigung unvollständig")
                    .font(.footnote.bold())
                    .foregroundColor(.white)
                Text("Automatisches Umschalten funktioniert bei gesperrtem Handy nur mit \"Immer erlauben\".")
                    .font(.caption)
                    .foregroundColor(Color(hex: "AAAAAA"))
            }
            Spacer(minLength: 8)
            Button("Öffnen", action: openLocationSettings)
                .font(.caption.bold())
                .foregroundColor(Color(hex: "2196F3"))
        }
        .padding(10)
        .background(Color(hex: "2A2A2A"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            squareButton(systemImage: "trash.fill", tint: Color(hex: "E53935"), enabled: !selectedIDs.isEmpty) {
                deleteSelected()
            }
            squareButton(systemImage: "pencil", tint: Color(hex: "FFA726"), enabled: selectedIDs.count == 1) {
                editSelected()
            }
            squareButton(systemImage: "checkmark", tint: Color(hex: "2196F3"), enabled: selectedIDs.count == 1) {
                setActiveSelected()
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                pillButton(systemImage: "arrow.up.left.and.arrow.down.right", isOn: connectionStore.edgeToEdge) {
                    connectionStore.edgeToEdge = true
                }
                pillButton(systemImage: "rectangle.topthird.inset.filled", isOn: !connectionStore.edgeToEdge) {
                    connectionStore.edgeToEdge = false
                }
            }
        }
    }

    private var connectionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(connectionStore.connections) { connection in
                    ConnectionRow(
                        connection: connection,
                        isActive: connection.url == connectionStore.activeConnectionUrl,
                        isSelected: selectedIDs.contains(connection.id),
                        onTap: { toggleSelection(connection.id) },
                        onPreview: { onPreview(connection.url) },
                        onConfigure: { configuringConnection = connection }
                    )
                }
            }
            .padding(16)
        }
        .background(Color(hex: "1A1A1A"))
    }

    private var bottomBar: some View {
        HStack {
            Image("X2BLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.black)
    }

    @ViewBuilder
    private func squareButton(systemImage: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(enabled ? tint : tint.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!enabled)
    }

    @ViewBuilder
    private func pillButton(systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundColor(isOn ? .black : .white)
                .frame(width: 40, height: 40)
                .background(isOn ? Color.white : Color.white.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private func toggleLocationSwitching() {
        LocationSwitchManager.shared.setEnabled(!connectionStore.locationSwitchingEnabled)
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func deleteSelected() {
        connectionStore.delete(ids: selectedIDs)
        selectedIDs.removeAll()
    }

    private func editSelected() {
        guard selectedIDs.count == 1,
              let id = selectedIDs.first,
              let connection = connectionStore.connections.first(where: { $0.id == id }) else { return }
        editingTarget = .edit(connection)
    }

    private func setActiveSelected() {
        guard selectedIDs.count == 1,
              let id = selectedIDs.first,
              let connection = connectionStore.connections.first(where: { $0.id == id }) else { return }
        connectionStore.setActive(url: connection.url)
        selectedIDs.removeAll()
    }
}

/// A single connection row, mirroring `item_connection.xml`.
private struct ConnectionRow: View {
    let connection: Connection
    let isActive: Bool
    let isSelected: Bool
    var onTap: () -> Void
    var onPreview: () -> Void
    var onConfigure: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // A plain Button, not `.onTapGesture` on the row - an ancestor's
            // .onTapGesture reliably swallows touches meant for a nested Button
            // (the eye button below), which is why neither tapping the row nor the
            // eye button ever fired reliably. Making both real, sibling Buttons
            // avoids that gesture conflict entirely.
            Button(action: onTap) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text(connection.url)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "AAAAAA"))
                        Text(connection.pushEnabled ? "Push-Benachrichtigungen: Aktiviert" : "Push-Benachrichtigungen: Ausgeschaltet")
                            .font(.system(size: 12))
                            .foregroundColor(connection.pushEnabled ? Color(hex: "4CAF50") : Color(hex: "888888"))
                    }

                    Spacer()

                    if isActive {
                        Image(systemName: "checkmark")
                            .foregroundColor(Color(hex: "4CAF50"))
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPreview) {
                Image(systemName: "eye.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onConfigure) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isSelected ? Color(hex: "37474F") : Color(hex: "2A2A2A"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
