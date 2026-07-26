//
//  X2BWidget.swift
//  X2BWidget
//

import WidgetKit
import SwiftUI

struct X2BWidgetEntry: TimelineEntry {
    let date: Date
    let slots: [ResolvedSlot]

    struct ResolvedSlot: Identifiable {
        let id: UUID
        let controlId: Int?
        let title: String
        let iconName: String
        let isOn: Bool
        let isAssigned: Bool
        let isActionable: Bool
        let isScene: Bool
        let valueText: String?
    }
}

struct X2BWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> X2BWidgetEntry {
        X2BWidgetEntry(date: Date(), slots: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (X2BWidgetEntry) -> Void) {
        Task { @MainActor in
            completion(await currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<X2BWidgetEntry>) -> Void) {
        Task { @MainActor in
            let entry = await currentEntry()
            // The box's state can change at any moment from something else entirely
            // (someone flips a physical switch, etc.) - a bounded validity window,
            // plus an explicit reload after every interactive tap (see
            // ToggleControlIntent), keeps this reasonably fresh without polling
            // constantly in the background.
            let nextRefresh = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    @MainActor
    private func currentEntry() async -> X2BWidgetEntry {
        let slotDefs = WidgetShared.readSlots()
        guard let boxUrl = WidgetShared.readBoxUrl(), !slotDefs.isEmpty else {
            return X2BWidgetEntry(date: Date(), slots: [])
        }

        let client = X2BWebSocketClient()
        let controls = await client.fetchControlsOnce(baseUrl: boxUrl, cookieOverride: WidgetShared.readCookies())

        let resolved = slotDefs.map { slot -> X2BWidgetEntry.ResolvedSlot in
            let control = slot.controlId.flatMap { controls[$0] }
            let isOn = control?.value.boolValue ?? false
            return X2BWidgetEntry.ResolvedSlot(
                id: slot.id,
                controlId: control?.id,
                title: control?.name ?? slot.controlName ?? slot.type.displayName,
                iconName: slot.type.icon(isOn: isOn),
                isOn: isOn,
                isAssigned: control != nil,
                isActionable: (control?.alterable ?? false) && slot.type.behavior != .readOnly,
                isScene: slot.type.behavior == .scene,
                valueText: slot.type.behavior == .readOnly ? control?.value.displayString : nil
            )
        }
        return X2BWidgetEntry(date: Date(), slots: resolved)
    }
}

struct X2BWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.widgetKind, provider: X2BWidgetProvider()) { entry in
            X2BWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("X2B")
        .description("Schnellzugriff auf deine X2B-Controls.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct X2BWidgetEntryView: View {
    let entry: X2BWidgetEntry

    var body: some View {
        if entry.slots.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.secondary)
                Text("Keine Box verbunden")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(entry.slots) { slot in
                    SlotTile(slot: slot)
                }
            }
        }
    }
}

private struct SlotTile: View {
    let slot: X2BWidgetEntry.ResolvedSlot

    var body: some View {
        if slot.isActionable, let controlId = slot.controlId {
            Button(intent: ToggleControlIntent(controlId: controlId, currentIsOn: slot.isOn, isScene: slot.isScene)) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 2) {
            Image(systemName: slot.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(slot.isAssigned ? (slot.isOn ? .green : .primary) : .secondary)
            Text(slot.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let valueText = slot.valueText {
                Text(valueText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(slot.isAssigned ? 1 : 0.35)
    }
}
