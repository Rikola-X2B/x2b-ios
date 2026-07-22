//
//  Connection.swift
//  x2b
//

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

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        status: String = "Aktiv",
        internalIp: String = "",
        systemId: String = "",
        pushEnabled: Bool = true,
        carPlaySlots: [CarPlaySlotAssignment] = CarPlaySlotAssignment.defaultSlots
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.status = status
        self.internalIp = internalIp
        self.systemId = systemId
        self.pushEnabled = pushEnabled
        self.carPlaySlots = carPlaySlots
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, url, status, internalIp, systemId, pushEnabled, carPlaySlots
    }

    // Manual Codable so connections persisted before carPlaySlots existed still decode
    // (missing key -> default slots) instead of failing to load entirely.
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
    }
}
