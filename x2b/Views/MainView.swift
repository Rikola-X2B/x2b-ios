//
//  MainView.swift
//  x2b
//

import SwiftUI

/// The visualization screen, mirroring Android's `MainActivity` / `activity_main.xml`:
/// a fullscreen WebView, a settings gear button floating near the bottom, and a
/// three-finger tap that also opens Settings.
struct MainView: View {
    @ObservedObject var connectionStore: ConnectionStore
    @ObservedObject private var pushManager = PushManager.shared

    /// Non-nil while previewing a connection from Settings without changing the active one,
    /// mirroring `MainActivity.EXTRA_PREVIEW_URL` / `previewActive`.
    var previewURL: String?
    var onOpenSettings: () -> Void

    @State private var errorMessage: String?

    private var activeURLString: String {
        previewURL ?? connectionStore.activeConnectionUrl
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let url = URL(string: activeURLString) {
                    X2BWebView(
                        url: url,
                        onLoginDetected: { pushManager.registerCurrentConnection(connectionStore) },
                        onLogoutDetected: { pushManager.unregisterCurrentConnection(connectionStore) },
                        onLoadError: { message in
                            withAnimation { errorMessage = "Fehler beim Laden: \(message)" }
                        }
                    )
                    .ignoresSafeArea(edges: connectionStore.edgeToEdge ? .all : [.horizontal, .bottom])
                }

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .position(x: geo.size.width * 0.65, y: geo.size.height - 17)

                ThreeFingerTapObserver(onTap: onOpenSettings)
                    .allowsHitTesting(false)
                    .frame(width: 0, height: 0)

                if let errorMessage {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .font(.footnote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 60)
                    }
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { self.errorMessage = nil }
                    }
                }
            }
        }
        .statusBar(hidden: connectionStore.edgeToEdge)
        .persistentSystemOverlays(connectionStore.edgeToEdge ? .hidden : .automatic)
    }
}
