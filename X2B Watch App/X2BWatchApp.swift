//
//  X2BWatchApp.swift
//  X2B Watch App
//

import SwiftUI

@main
struct X2BWatchApp: App {
    @StateObject private var connector = WatchConnector.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView(connector: connector)
        }
    }
}
