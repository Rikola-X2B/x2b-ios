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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
