//
//  CarPlaySlotsAssignmentView.swift
//  x2b
//

import SwiftUI

/// Lets the user assign each of a connection's 8 CarPlay grid slots to a type
/// (Garage/Licht/Schalter/Wertanzeige/Szene) and a specific real control fetched live
/// from that box over X2BCP. Pushed from `BoxSettingsView`, which owns the connection
/// to the box - by the time the user taps into this screen, the control list has
/// usually already loaded, instead of having to reconnect for every dialog.
struct CarPlaySlotsAssignmentView: View {
    let connection: Connection
    @ObservedObject var client: X2BWebSocketClient
    var onSave: (Connection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var slots: [CarPlaySlotAssignment]
    // Sorted once here instead of as a computed property read directly from
    // `client.controls` - that property was being re-sorted from scratch on every
    // single access, and each of the 8 slots' "Control" pickers reads it once per
    // body evaluation, so a box with many controls made the whole list noticeably
    // slow to become responsive while updates were still coming in.
    @State private var sortedControls: [X2BControl] = []

    init(connection: Connection, client: X2BWebSocketClient, onSave: @escaping (Connection) -> Void) {
        self.connection = connection
        self.client = client
        self.onSave = onSave
        var initialSlots = connection.carPlaySlots
        // Guard against a connection saved with a different slot count than 8
        // (shouldn't normally happen, but keeps the editor from crashing on it).
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
        .navigationTitle("CarPlay – \(connection.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    var updated = connection
                    updated.carPlaySlots = slots
                    onSave(updated)
                    dismiss()
                }
            }
        }
        // Covers both cases: controls that already arrived before this screen was
        // pushed (no further `onChange` would ever fire for those), and any that
        // arrive afterwards.
        .onAppear { sortedControls = client.controls.values.sorted { $0.name < $1.name } }
        .onChange(of: client.controls) { _, newControls in
            sortedControls = newControls.values.sorted { $0.name < $1.name }
        }
    }

    /// If the box hasn't reported this slot's previously-assigned control yet (e.g.
    /// not connected), fall back to the cached name from when it was assigned.
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
