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

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        status: String = "Aktiv",
        internalIp: String = "",
        systemId: String = "",
        pushEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.status = status
        self.internalIp = internalIp
        self.systemId = systemId
        self.pushEnabled = pushEnabled
    }
}
