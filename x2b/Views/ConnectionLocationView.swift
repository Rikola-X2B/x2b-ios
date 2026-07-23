//
//  ConnectionLocationView.swift
//  x2b
//

import SwiftUI
import MapKit
import CoreLocation

/// Lets the user pick where a box "lives" - tap the map or use the current location -
/// so `LocationSwitchManager` can later switch to it automatically via geofencing.
struct ConnectionLocationView: View {
    let connection: Connection
    var onSave: (Connection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var locator = OneShotLocator()

    init(connection: Connection, onSave: @escaping (Connection) -> Void) {
        self.connection = connection
        self.onSave = onSave
        let initial = connection.coordinate
        _coordinate = State(initialValue: initial)
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: initial ?? CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        ))
    }

    var body: some View {
        NavigationStack {
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

                VStack(spacing: 8) {
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if coordinate != nil {
                        Button("Standort entfernen", role: .destructive) {
                            coordinate = nil
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Standort – \(connection.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        var updated = connection
                        updated.latitude = coordinate?.latitude
                        updated.longitude = coordinate?.longitude
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
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
