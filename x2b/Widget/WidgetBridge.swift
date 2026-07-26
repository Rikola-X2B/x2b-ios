//
//  WidgetBridge.swift
//  x2b
//

import Foundation
import Combine
import WidgetKit

/// Keeps the App Group data X2BWidget reads (box URL, up to 4 CarPlay slots, auth
/// cookies) up to date, and asks WidgetKit to refresh whenever any of it changes.
///
/// Deliberately doesn't keep a live box connection open just for this - the widget
/// extension does its own one-shot fetch (`X2BWebSocketClient.fetchControlsOnce`)
/// whenever WidgetKit asks it for a timeline, the same reasoning as why
/// `CarPlayEntityStore`/`PhoneWatchConnector` only connect when actually needed.
@MainActor
final class WidgetBridge {
    static let shared = WidgetBridge()

    private var subscription: AnyCancellable?
    private var lastUrl: String?

    private init() {
        subscription = ConnectionStore.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.publish() }
            }
        publish()
    }

    private func publish() {
        guard let connection = ConnectionStore.shared.displayedConnection else {
            WidgetShared.writeBoxUrl(nil)
            WidgetShared.writeSlots([])
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
            return
        }

        WidgetShared.writeBoxUrl(connection.url)
        WidgetShared.writeSlots(Array(connection.carPlaySlots.prefix(4)))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)

        guard connection.url != lastUrl else { return }
        lastUrl = connection.url
        Task {
            let cookies = await WebViewCookies.matching(for: connection.url)
            let shared = cookies.map {
                WidgetShared.SharedCookie(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path)
            }
            WidgetShared.writeCookies(shared)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
        }
    }
}
