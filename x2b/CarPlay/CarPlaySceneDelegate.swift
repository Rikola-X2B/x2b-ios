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
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
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
        let buttons = CarPlayControl.simulationSet.map(gridButton)
        return CPGridTemplate(title: "X2B", gridButtons: buttons)
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
    }
}
