//
//  ConnectionEditView.swift
//  x2b
//

import SwiftUI

/// Add/edit form for a connection, mirroring `dialog_connection.xml` used by
/// `SettingsActivity.showConnectionDialog`. No `NavigationStack` of its own - callers
/// wrap it themselves, since it's used both as a standalone sheet (adding a new
/// connection) and pushed inside `BoxSettingsView`'s own stack ("Allgemein").
struct ConnectionEditView: View {
    let existing: Connection?
    var onSave: (Connection) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var url = ""
    @State private var pushEnabled = true
    @State private var fetchedInternalIp = "--"
    @State private var fetchedSystemId = "--"
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Name der Verbindung", text: $name)
                TextField(
                    "URL oder IP der X2B-Box (z. B. https://demo.x2.energy oder 192.168.1.50)",
                    text: $url
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .disableAutocorrection(true)
            }

            // Read-only, auto-fetched from the box's appconfig.json when editing.
            // Mirrors Android: shown live for information but never persisted.
            if existing != nil {
                Section("Interne IP-Adresse (LAN)") {
                    Text(fetchedInternalIp).foregroundStyle(.secondary)
                }
                Section("System-ID") {
                    Text(fetchedSystemId).foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Push-Benachrichtigungen für diese Box aktivieren", isOn: $pushEnabled)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(existing == nil ? "Verbindung hinzufügen" : "Allgemein")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Hinzufügen" : "Speichern", action: save)
            }
        }
        .onAppear(perform: populateFromExisting)
    }

    private func populateFromExisting() {
        guard let existing else {
            pushEnabled = true
            return
        }

        name = existing.name
        url = existing.url
        pushEnabled = existing.pushEnabled

        Task {
            let info = await AppConfigService.fetchInternalIpAndSystemId(baseUrl: existing.url)
            fetchedInternalIp = info.internalIp
            fetchedSystemId = info.systemId
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedUrl.isEmpty else {
            validationMessage = "Name und URL sind Pflichtfelder"
            return
        }

        let normalizedUrl = URLNormalizer.normalize(trimmedUrl)
        var connection = existing ?? Connection(name: trimmedName, url: normalizedUrl)
        connection.name = trimmedName
        connection.url = normalizedUrl
        connection.pushEnabled = pushEnabled

        onSave(connection)
        dismiss()
    }
}
