//
//  x2bApp.swift
//  x2b
//
//  Created by Andreas Berg on 26.12.2024.
//

import SwiftUI

@main
struct x2bApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Forces PhoneWatchConnector's singleton to initialize (and activate
    // WatchConnectivity) at launch, not lazily on first use.
    private let watchConnector = PhoneWatchConnector.shared
    // Same reasoning: if location-based switching was already enabled, resume
    // monitoring immediately on launch rather than waiting for Settings to be opened.
    private let locationSwitchManager = LocationSwitchManager.shared
    // Keeps the X2BWidget extension's App Group data current from the start, not
    // just whenever some other view happens to touch ConnectionStore first.
    private let widgetBridge = WidgetBridge.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
