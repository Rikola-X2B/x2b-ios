//
//  WatchSlotsAssignmentView.swift
//  x2b
//

import SwiftUI

/// Lets the user assign each of a connection's 8 Watch grid slots to a type
/// (Garage/Licht/Schalter/Wertanzeige/Szene) and a specific real control fetched live
/// from that box over X2BCP - independent from the CarPlay assignment, since a wrist
/// screen and a car dashboard call for different controls. Pushed from
/// `BoxSettingsView`, which owns the connection to the box.
struct WatchSlotsAssignmentView: View {
    let connection: Connection
    @ObservedObject var client: X2BWebSocketClient
    var onSave: (Connection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var slots: [CarPlaySlotAssignment]
    @State private var sortedControls: [X2BControl] = []

    init(connection: Connection, client: X2BWebSocketClient, onSave: @escaping (Connection) -> Void) {
        self.connection = connection
        self.client = client
        self.onSave = onSave
        var initialSlots = connection.watchSlots
        while initialSlots.count < 8 {
            initialSlots.append(CarPlaySlotAssignment(type: .switchGeneric, controlId: nil, controlName: nil))
        }
        _slots = State(initialValue: Array(initialSlots.prefix(8)))
    }

    var body: some View {
        List {
            ForEach(slots.indices, id: \.self) { index in
                Section("Slot \(index + 1)") {
                    Picker("Typ", selection: $slots[index].type) {
                        ForEach(CarPlaySlotType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Picker("Control", selection: controlBinding(at: index)) {
                        Text(controlPlaceholder(for: slots[index])).tag(Int?.none)
                        ForEach(sortedControls) { control in
                            Text(control.name).tag(Int?.some(control.id))
                        }
                    }
                }
            }
        }
        .navigationTitle("Watch – \(connection.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    var updated = connection
                    updated.watchSlots = slots
                    onSave(updated)
                    dismiss()
                }
            }
        }
        .onAppear { sortedControls = client.controls.values.sorted { $0.name < $1.name } }
        .onChange(of: client.controls) { _, newControls in
            sortedControls = newControls.values.sorted { $0.name < $1.name }
        }
    }

    private func controlPlaceholder(for slot: CarPlaySlotAssignment) -> String {
        if let controlId = slot.controlId, client.controls[controlId] == nil, let cachedName = slot.controlName {
            return "\(cachedName) (nicht verbunden)"
        }
        return "Nicht zugewiesen"
    }

    private func controlBinding(at index: Int) -> Binding<Int?> {
        Binding(
            get: { slots[index].controlId },
            set: { newId in
                slots[index].controlId = newId
                slots[index].controlName = newId.flatMap { client.controls[$0]?.name }
            }
        )
    }
}
