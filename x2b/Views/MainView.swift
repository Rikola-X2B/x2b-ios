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
        // `.ignoresSafeArea()` is applied to the GeometryReader itself (not just to
        // children) so `geo.size`/`geo.safeAreaInsets` reflect the true full-screen
        // bounds regardless of display mode - otherwise the reader is offered only the
        // safe-area-constrained space, the settings button never reaches the real
        // bottom edge, and toggling edge-to-edge has no visible effect at all.
        GeometryReader { geo in
            ZStack {
                Color.black

                if let url = URL(string: activeURLString) {
                    X2BWebView(
                        url: url,
                        onLoginDetected: { pushManager.registerCurrentConnection(connectionStore) },
                        onLogoutDetected: { pushManager.unregisterCurrentConnection(connectionStore) },
                        onLoadError: { message in
                            withAnimation { errorMessage = "Fehler beim Laden: \(message)" }
                        }
                    )
                    // Full bleed by default; only reserve the top status-bar area
                    // (never the sides/bottom) when not in edge-to-edge mode, matching
                    // Android's manual top-only inset padding.
                    .padding(.top, connectionStore.edgeToEdge ? 0 : geo.safeAreaInsets.top)
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
        .ignoresSafeArea()
        .statusBar(hidden: connectionStore.edgeToEdge)
        .persistentSystemOverlays(connectionStore.edgeToEdge ? .hidden : .automatic)
    }
}
