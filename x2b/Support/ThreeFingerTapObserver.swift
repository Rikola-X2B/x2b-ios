//
//  ThreeFingerTapObserver.swift
//  x2b
//

import SwiftUI
import UIKit

/// Detects a simultaneous three-finger touch anywhere on screen without intercepting or
/// consuming it, so the WebView underneath keeps scrolling/zooming as usual. This is the
/// iOS analog of Android's `GestureFrameLayout`.
///
/// The recognizer is attached to the key window (rather than a local view) because a
/// touch handled by the WebView's own internal view hierarchy would otherwise never
/// reach a plain sibling/overlay view.
final class ThreeFingerTapGestureRecognizer: UIGestureRecognizer {
    var onThreeFingerTap: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if event.allTouches?.count == 3 {
            onThreeFingerTap?()
        }
        // Never recognize/begin: this is a passive observer that must never
        // block or cancel any other gesture recognizer or touch delivery.
        state = .failed
    }
}

private final class WindowObserverView: UIView {
    var onWindowAvailable: ((UIWindow) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            onWindowAvailable?(window)
        }
    }
}

struct ThreeFingerTapObserver: UIViewRepresentable {
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = WindowObserverView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindowAvailable = { window in
            guard context.coordinator.recognizer.view == nil else { return }
            window.addGestureRecognizer(context.coordinator.recognizer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.recognizer.onThreeFingerTap = onTap
    }

    final class Coordinator {
        let recognizer = ThreeFingerTapGestureRecognizer()

        init(onTap: @escaping () -> Void) {
            recognizer.onThreeFingerTap = onTap
        }
    }
}
