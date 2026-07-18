//
//  DeviceIdentity.swift
//  x2b
//

import UIKit

/// Stable per-install device identifier, the iOS analog of Android's `ANDROID_ID`
/// used as the "serialNumber" sent when registering a push token with a box.
enum DeviceIdentity {
    static var serialNumber: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}
