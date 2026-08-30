//
//  RadioIntents.swift
//  X2BWidget
//

import AppIntents

/// "radioPlayer" controls (a Sonos favorite) report the currently playing favorite's
/// name as a string, or null when stopped. Playing one is a plain `SetControlValue`
/// with the favorite's name; an empty string or null stops it.

struct PlayRadioFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Radio-Favorit abspielen"
    static var description = IntentDescription("Spielt einen gespeicherten Sonos-Favoriten ab.")

    @Parameter(title: "Player")
    var control: X2BControlEntity

    @Parameter(title: "Favorit")
    var favoriteName: String

    init() {
        control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeRadioPlayer)
        favoriteName = ""
    }

    init(control: X2BControlEntity, favoriteName: String) {
        self.control = control
        self.favoriteName = favoriteName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await sendControlValue(.string(favoriteName), toControlId: control.id)
        return .result()
    }
}

struct StopRadioIntent: AppIntent {
    static var title: LocalizedStringResource = "Radio stoppen"
    static var description = IntentDescription("Stoppt die Wiedergabe eines Radio-Favoriten.")

    @Parameter(title: "Player")
    var control: X2BControlEntity

    init() { control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeRadioPlayer) }
    init(control: X2BControlEntity) { self.control = control }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Either an empty string or null means "stopped" per the API - null mirrors
        // what a stopped control's own value looks like at rest.
        await sendControlValue(.null, toControlId: control.id)
        return .result()
    }
}
