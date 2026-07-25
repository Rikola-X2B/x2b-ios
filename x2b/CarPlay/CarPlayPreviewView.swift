//
//  CarPlayPreviewView.swift
//  x2b
//

import SwiftUI

/// Phone-side preview of what the CarPlay screen shows for the active connection:
/// the same slots, the same live data, the same `CarPlayEntityStore` - just rendered
/// with SwiftUI instead of `CPGridTemplate` so it can be tried out without a car or
/// the CarPlay Simulator. Mirrors the real CarPlay grid showing only assigned slots,
/// with fewer/larger tiles the fewer of them there are.
struct CarPlayPreviewView: View {
    @StateObject private var store = CarPlayEntityStore.shared
    @Environment(\.dismiss) private var dismiss

    /// The slots actually shown, same rule as `CarPlaySceneDelegate.visibleSlots()`.
    private var visibleSlots: [CarPlaySlotAssignment] {
        let assigned = store.slots.filter { store.control(for: $0) != nil }
        return assigned.isEmpty ? store.slots : assigned
    }

    /// Mirrors CPGridTemplate's own layout rule (at most 2 rows): 1-2 slots -> that
    /// many columns, 3-4 -> 2x2, 5-6 -> 2x3, 7-8 -> 2x4.
    private func columnCount(for slotCount: Int) -> Int {
        switch slotCount {
        case 0, 1, 2: return max(slotCount, 1)
        case 3, 4: return 2
        case 5, 6: return 3
        default: return 4
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let slots = visibleSlots
                let columns = Array(
                    repeating: GridItem(.flexible()),
                    count: columnCount(for: slots.count)
                )

                ZStack {
                    Color.black

                    Image("X2BLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width, geo.size.height) * 0.55)
                        .opacity(0.08)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(slots) { slot in
                            CarPlaySlotTile(slot: slot, store: store)
                        }
                    }
                    .padding(28)
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(20)
            .background(Color.black)
            .navigationTitle("CarPlay – Vorschau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: store.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(store.isConnected ? Color(hex: "4CAF50") : Color(hex: "E53935"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { store.acquire() }
        .onDisappear { store.release() }
    }
}

private struct CarPlaySlotTile: View {
    let slot: CarPlaySlotAssignment
    @ObservedObject var store: CarPlayEntityStore

    private var control: X2BControl? { store.control(for: slot) }
    private var isOn: Bool { control?.value.boolValue ?? false }
    private var isAssigned: Bool { control != nil }

    private var isActionable: Bool {
        guard let control else { return false }
        return control.alterable && slot.type.behavior != .readOnly
    }

    var body: some View {
        Button(action: { store.performAction(for: slot) }) {
            VStack(spacing: 6) {
                Image(systemName: slot.type.icon(isOn: isOn))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(control?.name ?? slot.controlName ?? slot.type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if slot.type.behavior == .readOnly, let control {
                    Text(control.value.displayString)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "2196F3"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .opacity(isAssigned ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
    }

    private var iconColor: Color {
        guard isAssigned else { return Color(hex: "555555") }
        switch slot.type.behavior {
        case .toggle: return isOn ? Color(hex: "4CAF50") : Color(hex: "AAAAAA")
        case .scene: return Color(hex: "2196F3")
        case .readOnly: return Color(hex: "AAAAAA")
        }
    }

    private var tileBackground: Color {
        guard isAssigned else { return Color(hex: "2A2A2A") }
        switch slot.type.behavior {
        case .toggle: return isOn ? Color(hex: "4CAF50").opacity(0.18) : Color(hex: "2A2A2A")
        case .scene, .readOnly: return Color(hex: "2A2A2A")
        }
    }

    private var borderColor: Color {
        guard isAssigned else { return Color.white.opacity(0.05) }
        switch slot.type.behavior {
        case .toggle: return isOn ? Color(hex: "4CAF50") : Color.white.opacity(0.08)
        case .scene: return Color(hex: "2196F3").opacity(0.3)
        case .readOnly: return Color.white.opacity(0.08)
        }
    }
}
