//
//  ConnectionLocationView.swift
//  x2b
//

import SwiftUI
import MapKit
import CoreLocation

/// Lets the user pick where a box "lives" - tap the map or use the current location -
/// so `LocationSwitchManager` can later switch to it automatically via geofencing.
/// Pushed from `BoxSettingsView`, which owns the connection to the box.
struct ConnectionLocationView: View {
    let connection: Connection
    @ObservedObject var client: X2BWebSocketClient
    var onSave: (Connection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition
    @State private var presenceControlId: Int?
    @State private var presenceControlName: String?
    @State private var sortedControls: [X2BControl] = []
    @StateObject private var locator = OneShotLocator()

    init(connection: Connection, client: X2BWebSocketClient, onSave: @escaping (Connection) -> Void) {
        self.connection = connection
        self.client = client
        self.onSave = onSave
        let initial = connection.coordinate
        _coordinate = State(initialValue: initial)
        _presenceControlId = State(initialValue: connection.presenceControlId)
        _presenceControlName = State(initialValue: connection.presenceControlName)
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: initial ?? CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coordinate {
                        Marker(connection.name, coordinate: coordinate)
                    }
                }
                .onTapGesture { point in
                    if let tapped = proxy.convert(point, from: .local) {
                        coordinate = tapped
                    }
                }
            }
            .frame(height: 280)

            Form {
                Section {
                    Button {
                        locator.requestLocation { location in
                            coordinate = location.coordinate
                            cameraPosition = .region(MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            ))
                        }
                    } label: {
                        Label("Aktuellen Standort verwenden", systemImage: "location.fill")
                    }

                    if coordinate != nil {
                        Button("Standort entfernen", role: .destructive) {
                            coordinate = nil
                        }
                    }
                }

                Section {
                    Picker("Anwesenheits-Control", selection: presenceControlBinding) {
                        Text(presencePlaceholder).tag(Int?.none)
                        ForEach(sortedControls) { control in
                            Text(control.name).tag(Int?.some(control.id))
                        }
                    }
                } footer: {
                    Text("Wird auf 1 gesetzt, sobald du in der Nähe dieser Box bist, und auf 0, wenn du sie verlässt oder eine andere Box-Region betrittst.")
                }
            }
        }
        .navigationTitle("Standort – \(connection.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    var updated = connection
                    updated.latitude = coordinate?.latitude
                    updated.longitude = coordinate?.longitude
                    updated.presenceControlId = presenceControlId
                    updated.presenceControlName = presenceControlName
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

    private var presencePlaceholder: String {
        if let presenceControlId, client.controls[presenceControlId] == nil, let cachedName = presenceControlName {
            return "\(cachedName) (nicht verbunden)"
        }
        return "Nicht verknüpft"
    }

    private var presenceControlBinding: Binding<Int?> {
        Binding(
            get: { presenceControlId },
            set: { newId in
                presenceControlId = newId
                presenceControlName = newId.flatMap { client.controls[$0]?.name }
            }
        )
    }
}

/// A single `requestLocation()` call wrapped for SwiftUI - only ever needed here, to
/// center the map on "where I am right now" once per tap.
@MainActor
private final class OneShotLocator: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation(completion: @escaping (CLLocation) -> Void) {
        self.completion = completion
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }
}

extension OneShotLocator: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.completion?(location)
            self.completion = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🔎 [Location] one-shot request failed: \(error.localizedDescription)")
    }
}
