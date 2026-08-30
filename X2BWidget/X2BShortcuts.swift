//
//  X2BShortcuts.swift
//  X2BWidget
//

import AppIntents

/// Registers every control-affecting intent as an App Shortcut - the mechanism that
/// makes them directly reachable via "Hey Siri" without the user ever creating a
/// Shortcut by hand, since these are indexed automatically the first time this
/// extension runs. Named, single-utterance phrases ("Wohnzimmerlicht ausschalten")
/// need an intent whose parameter is resolved by name, which is what `TurnOnIntent`/
/// `TurnOffIntent` are for. `ToggleControlIntent` itself stays as-is for the widget's
/// own tap gesture - its parameters (a raw `controlId` plus the widget-only
/// `currentIsOn`/`isScene` flags) aren't voice-friendly, so its phrase doesn't
/// reference them - Siri falls back to asking for each one conversationally.
struct X2BShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleControlIntent(),
            phrases: ["\(.applicationName) Gerät umschalten"],
            shortTitle: "Gerät umschalten",
            systemImageName: "switch.2"
        )
        AppShortcut(
            intent: TurnOnIntent(),
            phrases: [
                "Schalte \(\.$control) in \(.applicationName) ein",
                "\(.applicationName): \(\.$control) einschalten",
            ],
            shortTitle: "Einschalten",
            systemImageName: "power"
        )
        AppShortcut(
            intent: TurnOffIntent(),
            phrases: [
                "Schalte \(\.$control) in \(.applicationName) aus",
                "\(.applicationName): \(\.$control) ausschalten",
            ],
            shortTitle: "Ausschalten",
            systemImageName: "power"
        )
        AppShortcut(
            intent: SetBlindPositionIntent(),
            phrases: [
                "Stelle den Rollladen \(\.$control) in \(.applicationName) auf \(\.$position) Prozent",
                "\(.applicationName): Rollladen \(\.$control) auf \(\.$position) Prozent",
            ],
            shortTitle: "Rollladen-Position",
            systemImageName: "blinds.horizontal.closed"
        )
        AppShortcut(
            intent: OpenBlindIntent(),
            phrases: [
                "Öffne den Rollladen \(\.$control) in \(.applicationName)",
                "\(.applicationName): Rollladen \(\.$control) öffnen",
            ],
            shortTitle: "Rollladen öffnen",
            systemImageName: "blinds.horizontal.open"
        )
        AppShortcut(
            intent: CloseBlindIntent(),
            phrases: [
                "Schliesse den Rollladen \(\.$control) in \(.applicationName)",
                "\(.applicationName): Rollladen \(\.$control) schliessen",
            ],
            shortTitle: "Rollladen schliessen",
            systemImageName: "blinds.horizontal.closed"
        )
        AppShortcut(
            intent: StopBlindIntent(),
            phrases: [
                "Stoppe den Rollladen \(\.$control) in \(.applicationName)",
                "\(.applicationName): Rollladen \(\.$control) stoppen",
            ],
            shortTitle: "Rollladen stoppen",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: PlayRadioFavoriteIntent(),
            phrases: [
                "Spiele \(\.$favoriteName) auf dem Radio \(\.$control) in \(.applicationName)",
                "\(.applicationName): \(\.$favoriteName) auf \(\.$control) abspielen",
            ],
            shortTitle: "Radio-Favorit abspielen",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StopRadioIntent(),
            phrases: [
                "Stoppe das Radio \(\.$control) in \(.applicationName)",
                "\(.applicationName): Radio \(\.$control) stoppen",
            ],
            shortTitle: "Radio stoppen",
            systemImageName: "stop.circle"
        )
    }
}
