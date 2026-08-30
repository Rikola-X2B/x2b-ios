//
//  BlindIntents.swift
//  X2BWidget
//

import AppIntents

/// "blind" controls (roller shutters/blinds) report and accept a 0-100 height
/// percentage: 0 = closed, 100 = open.

struct SetBlindPositionIntent: AppIntent {
    static var title: LocalizedStringResource = "Rollladen-Position setzen"
    static var description = IntentDescription("Setzt einen Rollladen oder eine Jalousie auf eine bestimmte Höhe in Prozent.")

    @Parameter(title: "Rollladen")
    var control: X2BControlEntity

    @Parameter(title: "Position (%)")
    var position: Int

    init() {
        control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeBlind)
        position = 0
    }

    init(control: X2BControlEntity, position: Int) {
        self.control = control
        self.position = position
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let clamped = min(max(position, 0), 100)
        await sendControlValue(.number(Double(clamped)), toControlId: control.id)
        return .result()
    }
}

struct OpenBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "Rollladen öffnen"
    static var description = IntentDescription("Öffnet einen Rollladen oder eine Jalousie vollständig.")

    @Parameter(title: "Rollladen")
    var control: X2BControlEntity

    init() { control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeBlind) }
    init(control: X2BControlEntity) { self.control = control }

    @MainActor
    func perform() async throws -> some IntentResult {
        await sendControlValue(.number(100), toControlId: control.id)
        return .result()
    }
}

struct CloseBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "Rollladen schliessen"
    static var description = IntentDescription("Schliesst einen Rollladen oder eine Jalousie vollständig.")

    @Parameter(title: "Rollladen")
    var control: X2BControlEntity

    init() { control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeBlind) }
    init(control: X2BControlEntity) { self.control = control }

    @MainActor
    func perform() async throws -> some IntentResult {
        await sendControlValue(.number(0), toControlId: control.id)
        return .result()
    }
}

struct StopBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "Rollladen stoppen"
    static var description = IntentDescription("Hält einen sich bewegenden Rollladen oder eine Jalousie an.")

    @Parameter(title: "Rollladen")
    var control: X2BControlEntity

    init() { control = X2BControlEntity(id: 0, name: "", type: X2BControl.typeBlind) }
    init(control: X2BControlEntity) { self.control = control }

    @MainActor
    func perform() async throws -> some IntentResult {
        // TODO: "blind" only has a documented 0-100 target-height value so far - there's
        // no defined "halt in place" encoding yet (a sentinel value? a dedicated future
        // command?). Left as a no-op placeholder until the server side settles that,
        // rather than guessing a value that could jam or misposition a real motor.
        return .result()
    }
}
