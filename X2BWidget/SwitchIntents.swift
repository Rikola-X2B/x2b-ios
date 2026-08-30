//
//  SwitchIntents.swift
//  X2BWidget
//

import AppIntents

/// Explicit on/off commands for "switch"/"light" controls, addressable by name via
/// Siri. Unlike `ToggleControlIntent` (used by the widget's own tap gesture, which
/// needs the control's current value to know which way to flip it), a spoken command
/// already states the desired end state directly, so there's nothing to look up first.

struct TurnOnIntent: AppIntent {
    static var title: LocalizedStringResource = "Einschalten"
    static var description = IntentDescription("Schaltet ein X2B-Gerät ein.")

    @Parameter(title: "Gerät")
    var control: X2BControlEntity

    init() { control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeSwitch) }
    init(control: X2BControlEntity) { self.control = control }

    @MainActor
    func perform() async throws -> some IntentResult {
        await sendControlValue(.bool(true), toControlId: control.id)
        return .result()
    }
}

struct TurnOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Ausschalten"
    static var description = IntentDescription("Schaltet ein X2B-Gerät aus.")

    @Parameter(title: "Gerät")
    var control: X2BControlEntity

    init() { control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeSwitch) }
    init(control: X2BControlEntity) { self.control = control }

    @MainActor
    func perform() async throws -> some IntentResult {
        await sendControlValue(.bool(false), toControlId: control.id)
        return .result()
    }
}
