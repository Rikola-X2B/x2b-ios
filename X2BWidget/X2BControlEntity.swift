//
//  X2BControlEntity.swift
//  X2BWidget
//

import AppIntents

/// A single X2B control, resolvable by name - lets a Siri/Shortcuts phrase pick a
/// device the way it's naturally said out loud ("Wohnzimmerlicht"), instead of
/// requiring a raw `controlId` the user could never plausibly speak.
struct X2BControlEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "X2B-Gerät"
    static var defaultQuery = X2BControlEntityQuery()

    let id: Int
    let name: String
    let type: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Fetches the active connection's controls the same way the widget's own
/// `TimelineProvider` does (`X2BWebSocketClient.fetchControlsOnce`) - a fresh,
/// one-shot connection per query, since this extension process has no live
/// connection of its own to read from.
struct X2BControlEntityQuery: EntityQuery {
    func entities(for identifiers: [X2BControlEntity.ID]) async throws -> [X2BControlEntity] {
        let all = await allControls()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [X2BControlEntity] {
        await allControls()
    }

    @MainActor
    private func allControls() async -> [X2BControlEntity] {
        guard let boxUrl = WidgetShared.readBoxUrl() else { return [] }
        let client = X2BWebSocketClient()
        let controls = await client.fetchControlsOnce(baseUrl: boxUrl, cookieOverride: WidgetShared.readCookies())
        return controls.values
            .map { X2BControlEntity(id: $0.id, name: $0.name, type: $0.type) }
            .sorted { $0.name < $1.name }
    }
}
