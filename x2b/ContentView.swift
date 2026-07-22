//
//  ContentView.swift
//  x2b
//
//  Created by Andreas Berg on 26.12.2024.
//

import SwiftUI

/// App root, wiring the visualization screen to Settings/preview navigation and the
/// forced-update overlay - the counterpart to Android's `MainActivity` owning both
/// the WebView and the Settings launch.
struct ContentView: View {
    @StateObject private var connectionStore = ConnectionStore.shared

    @State private var showSettings = false
    @State private var requiredUpdate: AppVersionChecker.UpdateInfo?

    var body: some View {
        ZStack {
            MainView(
                connectionStore: connectionStore,
                onOpenSettings: {
                    // Opening Settings again ends any active preview, so switching
                    // the active connection there always takes effect immediately -
                    // otherwise the preview would keep overriding it indefinitely for
                    // as long as the app process stays alive.
                    connectionStore.previewConnectionUrl = nil
                    showSettings = true
                }
            )

            if let requiredUpdate {
                ForcedUpdateView(storeURL: requiredUpdate.storeURL)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connectionStore: connectionStore) { url in
                connectionStore.previewConnectionUrl = url
                showSettings = false
            }
        }
        .task {
            requiredUpdate = await AppVersionChecker.checkForUpdate()
        }
    }
}

#Preview {
    ContentView()
}
