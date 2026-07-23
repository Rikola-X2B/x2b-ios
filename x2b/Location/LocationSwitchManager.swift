//
//  LocationSwitchManager.swift
//  x2b
//

import Combine
import CoreLocation

/// Automatically switches the active connection to whichever box's saved location
/// the phone is currently inside, using CoreLocation region monitoring (geofencing) -
/// event-driven and low-power, and (with "Always" authorization) works even while
/// the app isn't running, unlike continuous GPS tracking.
@MainActor
final class LocationSwitchManager: NSObject, ObservableObject {
    static let shared = LocationSwitchManager()

    /// Smaller risks false negatives from ordinary GPS accuracy noise; larger risks
    /// overlapping with a neighboring box's region. Fixed rather than exposed in the
    /// location picker UI to keep that simple - could become per-box later if needed.
    private static let regionRadius: CLLocationDistance = 250

    private let manager = CLLocationManager()
    private var connectionSubscription: AnyCancellable?

    private override init() {
        super.init()
        manager.delegate = self
        connectionSubscription = ConnectionStore.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshMonitoredRegions() }
            }
        refreshMonitoredRegions()
    }

    private var isEnabled: Bool { ConnectionStore.shared.locationSwitchingEnabled }

    /// Called from the GPS toggle in Settings - requesting authorization is a side
    /// effect of turning the feature on, not something to do proactively at launch.
    func setEnabled(_ enabled: Bool) {
        ConnectionStore.shared.locationSwitchingEnabled = enabled
        if enabled {
            requestAuthorizationIfNeeded()
        }
        refreshMonitoredRegions()
    }

    private func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Region monitoring keeps working in the background only with "Always" -
            // ask for the upgrade once "When In Use" is already granted.
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func refreshMonitoredRegions() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        guard isEnabled, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

        for connection in ConnectionStore.shared.connections {
            guard let coordinate = connection.coordinate else { continue }
            let region = CLCircularRegion(center: coordinate, radius: Self.regionRadius, identifier: connection.id.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }
}

extension LocationSwitchManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard let connection = ConnectionStore.shared.connections.first(where: { $0.id.uuidString == region.identifier }) else {
                return
            }
            ConnectionStore.shared.setActive(url: connection.url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse {
                self.manager.requestAlwaysAuthorization()
            }
            self.refreshMonitoredRegions()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("🔎 [Location] region monitoring failed for \(region?.identifier ?? "?"): \(error.localizedDescription)")
    }
}
