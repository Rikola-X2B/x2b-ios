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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
