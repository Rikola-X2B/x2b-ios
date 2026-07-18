//
//  PushManager.swift
//  x2b
//

import Foundation

/// Registers/unregisters this device's APNs token with the active X2B box on
/// login/logout, mirroring `MainActivity.sendFcmTokenToCurrentBox` /
/// `unregisterFcmTokenFromCurrentBox` on Android.
@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    @Published var deviceToken: String? {
        didSet {
            guard deviceToken != nil, pendingRegistration else { return }
            pendingRegistration = false
            registerCurrentConnection(ConnectionStore.shared)
        }
    }

    private var pendingRegistration = false

    private init() {}

    func registerCurrentConnection(_ store: ConnectionStore) {
        guard let connection = store.activeConnection, connection.pushEnabled else { return }
        guard let token = deviceToken else {
            pendingRegistration = true
            return
        }
        Task {
            await PushTokenService.send(
                action: .register,
                baseUrl: connection.url,
                token: token,
                serialNumber: DeviceIdentity.serialNumber
            )
        }
    }

    func unregisterCurrentConnection(_ store: ConnectionStore) {
        guard let token = deviceToken, let connection = store.activeConnection else { return }
        Task {
            await PushTokenService.send(
                action: .unregister,
                baseUrl: connection.url,
                token: token,
                serialNumber: DeviceIdentity.serialNumber
            )
        }
    }
}
