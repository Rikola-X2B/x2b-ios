//
//  CarPlaySceneDelegate.swift
//  x2b
//

import CarPlay
import Combine
import UIKit

/// Drives the actual CarPlay screen, granted under the "CarPlay driving task"
/// entitlement (Case-ID 10921911). Shows the active connection's assigned CarPlay
/// slots (up to 8, set in Settings) in a `CPGridTemplate` - CarPlay grid buttons
/// support at most 8, which is exactly our slot count, and CPGridTemplate itself lays
/// out however many are actually passed in as few rows as fit (bigger buttons for
/// fewer of them), which is why only assigned slots are shown at all.
@MainActor
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var storeSubscription: AnyCancellable?
    private let store = CarPlayEntityStore.shared

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        store.acquire()
        interfaceController.setRootTemplate(makeGridTemplate(), animated: true, completion: nil)

        // The store changes for lots of reasons (box pushes an update, connection
        // status flips, slot assignment gets edited in Settings) - keep the grid in
        // sync with all of them. `objectWillChange` fires before the store's own
        // properties are updated, so defer the actual re-read to the next runloop turn.
        storeSubscription = store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshGrid()
                }
            }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        storeSubscription = nil
        self.interfaceController = nil
        store.release()
    }

    private func makeGridTemplate() -> CPGridTemplate {
        let buttons = visibleSlots().map(gridButton)
        let template = CPGridTemplate(title: boxTitle(), gridButtons: buttons)
        template.trailingNavigationBarButtons = [connectionStatusButton()]
        return template
    }

    /// Only the slots that actually have a control assigned - CPGridTemplate lays
    /// buttons out in as few rows as fit (e.g. 4 buttons -> 2x2), so fewer, larger
    /// buttons for just what's actually configured beats always showing all 8
    /// including empty "Nicht zugewiesen" placeholders. Falls back to showing all 8
    /// if literally none are assigned yet, so the screen isn't just blank.
    private func visibleSlots() -> [CarPlaySlotAssignment] {
        let assigned = store.slots.filter { store.control(for: $0) != nil }
        return assigned.isEmpty ? store.slots : assigned
    }

    /// "X2B: <Boxname>, <Username>" - the box's hostname with the shared ".x2.energy"
    /// domain stripped off (since that part is the same for every box and just
    /// wastes space) and its first letter capitalized, followed by whichever user is
    /// currently logged in on the box, once that's loaded.
    private func boxTitle() -> String {
        guard let urlString = ConnectionStore.shared.displayedConnection?.url,
              let host = URL(string: urlString)?.host else {
            return "X2B"
        }
        let suffix = ".x2.energy"
        let shortName = host.hasSuffix(suffix) ? String(host.dropLast(suffix.count)) : host
        let boxName = shortName.prefix(1).uppercased() + shortName.dropFirst()

        guard !store.userName.isEmpty else { return "X2B: \(boxName)" }
        return "X2B: \(boxName), \(store.userName)"
    }

    private func connectionStatusButton() -> CPBarButton {
        let symbolName = store.isConnected ? "wifi" : "wifi.slash"
        let image = UIImage(systemName: symbolName) ?? UIImage()
        // Purely informational - reconnects happen automatically in the background,
        // there's nothing useful for a tap to do here.
        return CPBarButton(image: image) { _ in }
    }

    private func gridButton(for slot: CarPlaySlotAssignment) -> CPGridButton {
        let control = store.control(for: slot)
        let isOn = control?.value.boolValue ?? false
        let image = UIImage(systemName: slot.type.icon(isOn: isOn)) ?? UIImage()
        let button = CPGridButton(titleVariants: titleVariants(for: slot, control: control), image: image) { [weak self] _ in
            self?.store.performAction(for: slot)
        }
        return button
    }

    /// Most-to-least preferred, per `CPGridButton.titleVariants`'s own contract -
    /// CarPlay renders whichever variant actually fits the button's available space
    /// and otherwise falls back down the list, rather than wrapping or scrolling. A
    /// single "Name: Wert" string has no fallback of its own: if it doesn't fit on the
    /// real CarPlay screen, CarPlay just truncates it from the right, which silently
    /// drops exactly the value a "Wertanzeige" slot exists to show (the name comes
    /// first, the value after the colon). Listing the value alone as a shorter second
    /// variant lets it survive that truncation instead of disappearing.
    private func titleVariants(for slot: CarPlaySlotAssignment, control: X2BControl?) -> [String] {
        guard let control else {
            guard let controlName = slot.controlName else { return ["Nicht zugewiesen"] }
            return ["\(controlName) (nicht verbunden)", controlName]
        }
        if slot.type.behavior == .readOnly {
            return ["\(control.name): \(control.value.displayString)", control.value.displayString]
        }
        return [control.name]
    }

    private func refreshGrid() {
        // Recreated wholesale (rather than updateGridButtons + mutating title in
        // place) so the title stays correct too if the displayed box itself changed,
        // not just its buttons/status.
        guard interfaceController?.rootTemplate is CPGridTemplate else { return }
        interfaceController?.setRootTemplate(makeGridTemplate(), animated: false, completion: nil)
    }
}
