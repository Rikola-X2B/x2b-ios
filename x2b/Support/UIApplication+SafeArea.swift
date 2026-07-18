//
//  UIApplication+SafeArea.swift
//  x2b
//

import UIKit

extension UIApplication {
    /// The key window's safe area insets, read directly from UIKit rather than through a
    /// `GeometryReader` that also ignores the safe area - a reader's `.ignoresSafeArea()`
    /// affects what insets it reports to its own content, so this is a more reliable
    /// source for "how tall is the notch/status bar" independent of that.
    var keyWindowSafeAreaInsets: UIEdgeInsets {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
}
