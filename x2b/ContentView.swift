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
    @State private var previewURL: String?
    @State private var requiredUpdate: AppVersionChecker.UpdateInfo?

    var body: some View {
        ZStack {
            MainView(
                connectionStore: connectionStore,
                previewURL: previewURL,
                onOpenSettings: { showSettings = true }
            )

            if let requiredUpdate {
                ForcedUpdateView(storeURL: requiredUpdate.storeURL)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(connectionStore: connectionStore) { url in
                previewURL = url
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
