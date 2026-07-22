//
//  CarPlaySceneDelegate.swift
//  x2b
//

import CarPlay
import Combine
import UIKit

/// Drives the actual CarPlay screen, granted under the "CarPlay driving task"
/// entitlement (Case-ID 10921911). Shows the same 8 controls as the phone-side
/// mockup (`CarPlaySimulationView`) in a `CPGridTemplate` - CarPlay grid buttons
/// support at most 8, which is exactly our control count.
///
/// Still backed by the local, in-memory `CarPlaySimulationStore` rather than a real
/// server call - there is no `/api/v1` on the box yet (see the CarPlay proposal).
/// Swapping that out later shouldn't require touching this file's structure, only
/// where `handleTap` gets its data from.
@MainActor
final class CarPlaySceneDelegate: NSObject, @preconcurrency CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var storeSubscription: AnyCancellable?
    private let store = CarPlaySimulationStore.shared

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(makeGridTemplate(), animated: true, completion: nil)

        // The store can also change from the phone-side mockup while CarPlay is
        // connected; keep the grid in sync either way. `objectWillChange` fires
        // synchronously from `willSet`, before the new value is actually stored, so
        // reading the store immediately would see the stale value - defer to the
        // next runloop turn instead.
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
    }

    private func makeGridTemplate() -> CPGridTemplate {
        // No title text - CPGridTemplate has no API for a custom background/logo
        // image (CarPlay renders that chrome itself), and the app's own icon
        // already shows in the CarPlay sidebar, so a redundant "X2B" text title
        // isn't worth the space. The freed-up top area instead gets a connection
        // status icon via the nav bar buttons every CPTemplate supports.
        let buttons = CarPlayControl.simulationSet.map(gridButton)
        let template = CPGridTemplate(title: nil, gridButtons: buttons)
        template.trailingNavigationBarButtons = [connectionStatusButton()]
        return template
    }

    private func connectionStatusButton() -> CPBarButton {
        // Simulated only - no real reachability check against the box yet, since
        // /api/v1.1 doesn't exist there yet. Tapping it toggles the simulated state
        // so both visual states can be tried out.
        let symbolName = store.isConnected ? "wifi" : "wifi.slash"
        let image = UIImage(systemName: symbolName) ?? UIImage()
        return CPBarButton(image: image) { [weak self] _ in
            self?.store.toggleConnection()
        }
    }

    private func gridButton(for control: CarPlayControl) -> CPGridButton {
        let isOn = store.isOn(control)
        let image = UIImage(systemName: control.icon(isOn: isOn)) ?? UIImage()
        return CPGridButton(titleVariants: [control.name], image: image) { [weak self] _ in
            self?.handleTap(on: control)
        }
    }

    private func handleTap(on control: CarPlayControl) {
        if control.isToggle {
            store.toggle(control)
        } else {
            store.fireScene(control)
        }
        // `store.toggle`/`fireScene` already trigger `objectWillChange`, so the
        // `sink` above will refresh the grid - no need to do it again here.
    }

    private func refreshGrid() {
        guard let gridTemplate = interfaceController?.rootTemplate as? CPGridTemplate else { return }
        gridTemplate.updateGridButtons(CarPlayControl.simulationSet.map(gridButton))
        gridTemplate.trailingNavigationBarButtons = [connectionStatusButton()]
    }
}
