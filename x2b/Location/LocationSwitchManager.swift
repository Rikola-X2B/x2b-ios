//
//  LocationSwitchManager.swift
//  x2b
//

import Combine
import CoreLocation

/// Automatically switches the active connection to whichever box's saved location
/// (and freely adjustable radius, `Connection.geofenceRadius`) the phone is currently
/// inside, using CoreLocation region monitoring (geofencing) - event-driven and
/// low-power, and (with "Always" authorization) works even while the app isn't
/// running, unlike continuous GPS tracking. Also sets each box's optional presence
/// control to true on entering its region and back to false on leaving it (or
/// entering another box's region).
@MainActor
final class LocationSwitchManager: NSObject, ObservableObject {
    static let shared = LocationSwitchManager()

    /// Whether region monitoring can actually wake the app while it's backgrounded or
    /// the phone is locked - only true with `.authorizedAlways`. iOS's automatic
    /// When-In-Use -> Always upgrade prompt isn't reliably shown (it depends on prior
    /// user choices and isn't guaranteed to reappear just because we ask again), so
    /// callers should surface this and point the user at Settings instead of assuming
    /// the upgrade request alone fixed it.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var connectionSubscription: AnyCancellable?

    private override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
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
        guard isEnabled, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            DebugLog.log("🔎 [Location] not monitoring (enabled=\(isEnabled), authorization=\(authorizationStatus.rawValue))")
            return
        }

        for connection in ConnectionStore.shared.connections {
            guard let coordinate = connection.coordinate else { continue }
            let region = CLCircularRegion(center: coordinate, radius: connection.geofenceRadius, identifier: connection.id.uuidString)
            region.notifyOnEntry = true
            // Also needed now: leaving a box's own region (not just entering another
            // one) has to clear its presence control back to false on its own.
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            DebugLog.log("🔎 [Location] monitoring \"\(connection.name)\", radius=\(Int(connection.geofenceRadius))m")
        }
    }

    /// Opens a short-lived connection just to send one `SetControlValue` and tears
    /// it back down - a presence control update is a one-off side effect of a region
    /// crossing, not something that needs a socket kept open afterwards.
    private func setPresence(for connection: Connection, isPresent: Bool) {
        guard let controlId = connection.presenceControlId else { return }
        let socket = X2BWebSocketClient()
        socket.connect(baseUrl: connection.url, trackLiveUpdates: false)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            socket.setControlValue(id: controlId, value: .bool(isPresent))
            try? await Task.sleep(nanoseconds: 500_000_000)
            socket.disconnect()
        }
    }
}

extension LocationSwitchManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            DebugLog.log("🔎 [Location] didEnterRegion \(region.identifier)")
            guard let connection = ConnectionStore.shared.connections.first(where: { $0.id.uuidString == region.identifier }) else {
                DebugLog.log("🔎 [Location] no connection matches region \(region.identifier) (deleted since?)")
                return
            }
            // A leftover "Vorschau" preview (see ContentView/SettingsView) takes
            // priority over the active connection in `displayedConnection` - without
            // clearing it here, an automatic geofence switch would silently update
            // `activeConnectionUrl` while the screen kept showing the previewed box
            // until Settings was opened again (which is the only other place that
            // clears the preview).
            ConnectionStore.shared.previewConnectionUrl = nil
            ConnectionStore.shared.setActive(url: connection.url)
            DebugLog.log("🔎 [Location] switched active connection to \"\(connection.name)\"")
            self.setPresence(for: connection, isPresent: true)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            DebugLog.log("🔎 [Location] didExitRegion \(region.identifier)")
            guard let connection = ConnectionStore.shared.connections.first(where: { $0.id.uuidString == region.identifier }) else {
                return
            }
            self.setPresence(for: connection, isPresent: false)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            DebugLog.log("🔎 [Location] authorization changed: \(manager.authorizationStatus.rawValue)")
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse {
                self.manager.requestAlwaysAuthorization()
            }
            self.refreshMonitoredRegions()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            DebugLog.log("🔎 [Location] region monitoring failed for \(region?.identifier ?? "?"): \(error.localizedDescription)")
        }
    }
}
