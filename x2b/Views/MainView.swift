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

    var onOpenSettings: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var errorMessage: String?
    // A background geofence switch (LocationSwitchManager.setActive) updates
    // ConnectionStore while the app isn't being drawn at all - SwiftUI records the
    // change but doesn't reliably re-render an off-screen body just for it, so the
    // WebView can still be showing the old box's page for a while after unlocking
    // or reopening the app, until *something* forces a fresh body evaluation.
    // Toggling this on returning to the foreground is that something.
    @State private var foregroundRefreshTrigger = false

    // Read from UIKit rather than `geo.safeAreaInsets`, since a GeometryReader that
    // ignores the safe area on itself can't be trusted to still report it. Stored as
    // @State, updated only from `.onAppear`/`.onChange` (never read live during body
    // computation) - querying the key window's safe area synchronously from inside a
    // computed property used by this same view's body creates a real dependency cycle
    // ("AttributeGraph: cycle detected"), which on-device silently broke updates to
    // everything else computed in that render pass, including the active/preview URL.
    @State private var topSafeAreaInset: CGFloat = 0

    private var activeURLString: String {
        // Read, not just declared as a dependency - `foregroundRefreshTrigger` itself
        // is meaningless, but SwiftUI only re-evaluates `body` for state it can see
        // was actually read while computing it, so this line is what makes the
        // toggle in `.onChange(of: scenePhase)` below actually matter.
        _ = foregroundRefreshTrigger
        return connectionStore.displayedConnection?.url ?? ""
    }

    var body: some View {
        // `.ignoresSafeArea()` is applied to the GeometryReader itself (not just to
        // children) so `geo.size` reflects the true full-screen bounds regardless of
        // display mode - otherwise the reader is offered only the safe-area-constrained
        // space and the settings button never reaches the real bottom edge. The top
        // inset itself is read separately via `topSafeAreaInset` (UIKit), since a reader
        // that ignores the safe area on itself can't be trusted to still report it.
        GeometryReader { geo in
            ZStack(alignment: .top) {
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
                    .padding(.top, connectionStore.edgeToEdge ? 0 : topSafeAreaInset)
                }

                // Explicit solid bar reserving the status-bar area, mirroring Android's
                // dedicated `top_black_bar` view - drawn on top rather than relying on
                // the base Color.black showing through, so it's guaranteed visible
                // regardless of how the WebView itself lays out its content underneath.
                if !connectionStore.edgeToEdge {
                    Color.black
                        .frame(height: topSafeAreaInset)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
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
            .onAppear { topSafeAreaInset = UIApplication.shared.keyWindowSafeAreaInsets.top }
            .onChange(of: geo.size) { _, _ in
                topSafeAreaInset = UIApplication.shared.keyWindowSafeAreaInsets.top
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: connectionStore.edgeToEdge)
        .persistentSystemOverlays(connectionStore.edgeToEdge ? .hidden : .automatic)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                foregroundRefreshTrigger.toggle()
            }
        }
    }
}
