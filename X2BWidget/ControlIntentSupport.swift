//
//  ControlIntentSupport.swift
//  X2BWidget
//

import Foundation
import WidgetKit

/// Shared connect/send/disconnect sequence for the Siri/Shortcuts intents below - the
/// same one-shot, short-lived connection pattern as `ToggleControlIntent` and the
/// widget's own `TimelineProvider`, since an intent's extension process can't rely on
/// anything staying connected between invocations.
@MainActor
func sendControlValue(_ value: X2BControlValue, toControlId controlId: Int) async {
    guard let boxUrl = WidgetShared.readBoxUrl() else { return }
    let client = X2BWebSocketClient()
    client.connect(baseUrl: boxUrl, trackLiveUpdates: false, cookieOverride: WidgetShared.readCookies())
    // Give the handshake a moment before sending, same reasoning as ToggleControlIntent.
    try? await Task.sleep(nanoseconds: 1_500_000_000)
    client.setControlValue(id: controlId, value: value)
    try? await Task.sleep(nanoseconds: 400_000_000)
    client.disconnect()
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
}
