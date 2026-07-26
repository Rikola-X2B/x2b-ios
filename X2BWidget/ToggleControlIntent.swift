//
//  ToggleControlIntent.swift
//  X2BWidget
//

import AppIntents
import WidgetKit
import Foundation

/// Lets a widget button act on a control directly, without opening the app - runs in
/// the widget extension's own process, so it opens its own short-lived connection to
/// the box (reusing the shared `X2BWebSocketClient`) rather than reaching into
/// anything living in the main app.
struct ToggleControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Control umschalten"
    static var description = IntentDescription("Schaltet ein X2B-Control direkt aus dem Widget.")

    @Parameter(title: "Control-ID")
    var controlId: Int

    @Parameter(title: "Aktueller Wert")
    var currentIsOn: Bool

    /// Scene-type slots (e.g. "Ankommen"/"Gehen") always send true - they're
    /// momentary pushbuttons, not a persistent on/off state to negate.
    @Parameter(title: "Ist Szene")
    var isScene: Bool

    init() {
        controlId = 0
        currentIsOn = false
        isScene = false
    }

    init(controlId: Int, currentIsOn: Bool, isScene: Bool) {
        self.controlId = controlId
        self.currentIsOn = currentIsOn
        self.isScene = isScene
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let boxUrl = WidgetShared.readBoxUrl() else { return .result() }

        let client = X2BWebSocketClient()
        client.connect(baseUrl: boxUrl, trackLiveUpdates: false, cookieOverride: WidgetShared.readCookies())
        // Give the handshake a moment before sending, same reasoning as
        // LocationSwitchManager's presence-control updates - and tear back down
        // right after, rather than keeping a connection open in this process.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        client.setControlValue(id: controlId, value: .bool(isScene ? true : !currentIsOn))
        try? await Task.sleep(nanoseconds: 400_000_000)
        client.disconnect()

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
        return .result()
    }
}
