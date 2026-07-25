//
//  WatchContentView.swift
//  X2B Watch App
//

import SwiftUI

/// The Watch's main (and only) screen: swipe left/right between the assigned
/// controls via the native watchOS page style, tap the current one to act on it.
struct WatchContentView: View {
    @ObservedObject var connector: WatchConnector

    var body: some View {
        Group {
            if connector.payload.slots.isEmpty {
                emptyState
            } else {
                TabView {
                    ForEach(connector.payload.slots) { slot in
                        WatchSlotPage(slot: slot, isConnected: connector.payload.isConnected) {
                            connector.perform(slot)
                        }
                    }
                }
                .tabViewStyle(.page)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Keine Controls zugewiesen. In der X2B-App unter Einstellungen → Uhr-Symbol einrichten.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

private struct WatchSlotPage: View {
    let slot: WatchSlotState
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: slot.iconName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(iconColor)
                    Text(slot.title)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if let valueText = slot.valueText {
                        Text(valueText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(!slot.isActionable)
            .opacity(slot.isAssigned ? 1 : 0.4)

            Image(systemName: isConnected ? "wifi" : "wifi.slash")
                .font(.system(size: 10))
                .foregroundColor(isConnected ? .green : .red)
        }
    }

    private var iconColor: Color {
        guard slot.isAssigned else { return .secondary }
        return slot.isOn ? .green : .primary
    }
}
