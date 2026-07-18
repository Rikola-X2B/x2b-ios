//
//  ForcedUpdateView.swift
//  x2b
//

import SwiftUI

/// Blocking "update required" overlay, shown instead of the normal UI when
/// `AppVersionChecker` finds a newer App Store release. There is no dismiss
/// action, matching Android's forced immediate-update flow.
struct ForcedUpdateView: View {
    let storeURL: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
                Text("Update erforderlich")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Es ist eine neue Version von X2B verfügbar. Bitte aktualisiere die App, um fortzufahren.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 32)
                Button {
                    UIApplication.shared.open(storeURL)
                } label: {
                    Text("Jetzt aktualisieren")
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "2196F3"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
