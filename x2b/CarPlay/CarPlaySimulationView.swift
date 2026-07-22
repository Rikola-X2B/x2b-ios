//
//  CarPlaySimulationView.swift
//  x2b
//

import SwiftUI

/// A local mockup of what the CarPlay dashboard would look like: an X2B-branded
/// background with 8 control tiles laid over it. No network calls - this exists to
/// validate the layout/interaction before the real CarPlay entitlement is approved
/// and before the box exposes the `/api/v1` entity endpoints.
struct CarPlaySimulationView: View {
    @StateObject private var store = CarPlaySimulationStore.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black

                    Image("X2BLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width, geo.size.height) * 0.55)
                        .opacity(0.08)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(CarPlayControl.simulationSet) { control in
                            CarPlayControlTile(control: control, store: store)
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
            .navigationTitle("CarPlay (Simulation)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Mirrors the connection-status button in the real CarPlay nav
                    // bar - simulated only, tap to try out both states.
                    Button(action: { store.toggleConnection() }) {
                        Image(systemName: store.isConnected ? "wifi" : "wifi.slash")
                            .foregroundColor(store.isConnected ? Color(hex: "4CAF50") : Color(hex: "E53935"))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct CarPlayControlTile: View {
    let control: CarPlayControl
    @ObservedObject var store: CarPlaySimulationStore

    var body: some View {
        Button(action: performAction) {
            VStack(spacing: 8) {
                Image(systemName: control.icon(isOn: isOn))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(control.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor, lineWidth: isFired ? 2 : 1)
            )
            .scaleEffect(isFired ? 0.95 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isFired)
    }

    private var isOn: Bool { store.isOn(control) }
    private var isFired: Bool { store.recentlyFired.contains(control.id) }

    private var iconColor: Color {
        switch control.kind {
        case .toggle: return isOn ? Color(hex: "4CAF50") : Color(hex: "AAAAAA")
        case .scene: return Color(hex: "2196F3")
        }
    }

    private var tileBackground: Color {
        switch control.kind {
        case .toggle: return isOn ? Color(hex: "4CAF50").opacity(0.18) : Color(hex: "2A2A2A")
        case .scene: return isFired ? Color(hex: "2196F3").opacity(0.3) : Color(hex: "2A2A2A")
        }
    }

    private var borderColor: Color {
        switch control.kind {
        case .toggle: return isOn ? Color(hex: "4CAF50") : Color.white.opacity(0.08)
        case .scene: return Color(hex: "2196F3").opacity(isFired ? 0.9 : 0.3)
        }
    }

    private func performAction() {
        switch control.kind {
        case .toggle: store.toggle(control)
        case .scene: store.fireScene(control)
        }
    }
}

#Preview {
    CarPlaySimulationView()
}
