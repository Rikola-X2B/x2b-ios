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
        // No title text - CPGridTemplate has no API for a custom background/logo
        // image (CarPlay renders that chrome itself), and the app's own icon
        // already shows in the CarPlay sidebar, so a redundant "X2B" text title
        // isn't worth the space. The freed-up top area instead gets a connection
        // status icon via the nav bar buttons every CPTemplate supports.
        let buttons = store.slots.map(gridButton)
        let template = CPGridTemplate(title: nil, gridButtons: buttons)
        template.trailingNavigationBarButtons = [connectionStatusButton()]
        return template
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
        guard let gridTemplate = interfaceController?.rootTemplate as? CPGridTemplate else { return }
        gridTemplate.updateGridButtons(store.slots.map(gridButton))
        gridTemplate.trailingNavigationBarButtons = [connectionStatusButton()]
    }
}
