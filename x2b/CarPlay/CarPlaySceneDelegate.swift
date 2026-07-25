//
//  CarPlaySceneDelegate.swift
//  x2b
//

import CarPlay
import Combine
import UIKit

/// Drives the actual CarPlay screen, granted under the "CarPlay driving task"
/// entitlement (Case-ID 10921911). Shows the active connection's 8 CarPlay slots
/// (assigned in Settings) in a `CPGridTemplate` - CarPlay grid buttons support at
/// most 8, which is exactly our slot count.
@MainActor
final class CarPlaySceneDelegate: NSObject, @preconcurrency CPTemplateApplicationSceneDelegate {
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
        let buttons = store.slots.map(gridButton)
        let template = CPGridTemplate(title: boxTitle(), gridButtons: buttons)
        template.trailingNavigationBarButtons = [connectionStatusButton()]
        return template
    }

    /// "X2B: <Boxname>" - the box's hostname with the shared ".x2.energy" domain
    /// stripped off, since that part is the same for every box and just wastes space.
    private func boxTitle() -> String {
        guard let urlString = ConnectionStore.shared.displayedConnection?.url,
              let host = URL(string: urlString)?.host else {
            return "X2B"
        }
        let suffix = ".x2.energy"
        let shortName = host.hasSuffix(suffix) ? String(host.dropLast(suffix.count)) : host
        return "X2B: \(shortName)"
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
        let button = CPGridButton(titleVariants: [displayTitle(for: slot, control: control)], image: image) { [weak self] _ in
            self?.store.performAction(for: slot)
        }
        return button
    }

    private func displayTitle(for slot: CarPlaySlotAssignment, control: X2BControl?) -> String {
        guard let control else {
            return slot.controlName.map { "\($0) (nicht verbunden)" } ?? "Nicht zugewiesen"
        }
        if slot.type.behavior == .readOnly, case .string(let text) = control.value {
            return "\(control.name): \(text)"
        }
        return control.name
    }

    private func refreshGrid() {
        // Recreated wholesale (rather than updateGridButtons + mutating title in
        // place) so the title stays correct too if the displayed box itself changed,
        // not just its buttons/status.
        guard interfaceController?.rootTemplate is CPGridTemplate else { return }
        interfaceController?.setRootTemplate(makeGridTemplate(), animated: false, completion: nil)
    }
}
