//
//  Connection.swift
//  x2b
//

import CoreLocation
import Foundation

/// A single X2B box connection, mirroring `energy.inno.x2b.v2.Connection` on Android.
struct Connection: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var status: String
    var internalIp: String
    var systemId: String
    var pushEnabled: Bool
    var carPlaySlots: [CarPlaySlotAssignment]
    /// Independent from `carPlaySlots` - the user picks a separate 8-control layout
    /// for the Watch, since a car dashboard and a wrist screen call for different
    /// controls (and each is set up per device anyway, not synced to the box).
    var watchSlots: [CarPlaySlotAssignment]
    /// Where this box "lives", for `LocationSwitchManager`'s geofencing - nil means
    /// no location has been set yet, so this connection is never auto-switched to.
    var latitude: Double?
    var longitude: Double?
    /// A boolean control that `LocationSwitchManager` sets to true on arriving in
    /// this box's region, and back to false on leaving it (or entering another box's
    /// region) - e.g. an "anwesend"/presence indicator. `controlName` is cached at
    /// assignment time purely for display, same reasoning as `CarPlaySlotAssignment`.
    var presenceControlId: Int?
    var presenceControlName: String?
    /// Radius in meters of this box's geofence, freely adjustable per box - 250m by
    /// default (small enough to avoid overlapping a neighboring box, large enough to
    /// absorb ordinary GPS accuracy noise).
    var geofenceRadius: Double

    static let defaultGeofenceRadius: Double = 250

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        status: String = "Aktiv",
        internalIp: String = "",
        systemId: String = "",
        pushEnabled: Bool = true,
        carPlaySlots: [CarPlaySlotAssignment] = CarPlaySlotAssignment.defaultSlots,
        watchSlots: [CarPlaySlotAssignment] = CarPlaySlotAssignment.defaultSlots,
        latitude: Double? = nil,
        longitude: Double? = nil,
        presenceControlId: Int? = nil,
        presenceControlName: String? = nil,
        geofenceRadius: Double = Connection.defaultGeofenceRadius
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.status = status
        self.internalIp = internalIp
        self.systemId = systemId
        self.pushEnabled = pushEnabled
        self.carPlaySlots = carPlaySlots
        self.watchSlots = watchSlots
        self.latitude = latitude
        self.longitude = longitude
        self.presenceControlId = presenceControlId
        self.presenceControlName = presenceControlName
        self.geofenceRadius = geofenceRadius
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, url, status, internalIp, systemId, pushEnabled, carPlaySlots, watchSlots
        case latitude, longitude, presenceControlId, presenceControlName, geofenceRadius
    }

    // Manual Codable so connections persisted before carPlaySlots/watchSlots/location/
    // presence existed still decode (missing key -> default/nil) instead of failing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        status = try container.decode(String.self, forKey: .status)
        internalIp = try container.decode(String.self, forKey: .internalIp)
        systemId = try container.decode(String.self, forKey: .systemId)
        pushEnabled = try container.decode(Bool.self, forKey: .pushEnabled)
        carPlaySlots = try container.decodeIfPresent([CarPlaySlotAssignment].self, forKey: .carPlaySlots)
            ?? CarPlaySlotAssignment.defaultSlots
        watchSlots = try container.decodeIfPresent([CarPlaySlotAssignment].self, forKey: .watchSlots)
            ?? CarPlaySlotAssignment.defaultSlots
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        presenceControlId = try container.decodeIfPresent(Int.self, forKey: .presenceControlId)
        presenceControlName = try container.decodeIfPresent(String.self, forKey: .presenceControlName)
        geofenceRadius = try container.decodeIfPresent(Double.self, forKey: .geofenceRadius)
            ?? Connection.defaultGeofenceRadius
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(status, forKey: .status)
        try container.encode(internalIp, forKey: .internalIp)
        try container.encode(systemId, forKey: .systemId)
        try container.encode(pushEnabled, forKey: .pushEnabled)
        try container.encode(carPlaySlots, forKey: .carPlaySlots)
        try container.encode(watchSlots, forKey: .watchSlots)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(presenceControlId, forKey: .presenceControlId)
        try container.encodeIfPresent(presenceControlName, forKey: .presenceControlName)
        try container.encode(geofenceRadius, forKey: .geofenceRadius)
    }
}
