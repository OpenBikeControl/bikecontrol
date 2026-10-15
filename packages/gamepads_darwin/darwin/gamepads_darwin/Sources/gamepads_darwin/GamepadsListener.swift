import Foundation
import GameController

struct ConnectedGamepad {
    let id: Int
    let controller: GCController
    let gamepad: GCExtendedGamepad
}

class GamepadsListener {
    private(set) var gamepads: [ConnectedGamepad] = []
    var listener: ((Int, GCExtendedGamepad, GCControllerElement) -> Void)?
    var connectionListener: ((Int, GCController, Bool) -> Void)?

    /// Identifiers are handed out in order and never reused, so an identifier
    /// captured by an event handler keeps pointing at the same controller even
    /// after other controllers disconnect.
    private var nextId = 0

    init() {
        #if os(macOS)
        // Keep receiving input while the trainer app (Zwift, MyWhoosh, ...)
        // has focus; by default GameController only delivers it to the
        // frontmost app.
        if #available(macOS 11.3, *) {
            GCController.shouldMonitorBackgroundEvents = true
        }
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(joystickDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(joystickDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Controllers that were already connected when the plugin was
        // registered do not produce a connection notification.
        for controller in GCController.controllers() {
            addGamepad(controller: controller)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        for entry in gamepads {
            entry.gamepad.valueChangedHandler = nil
        }
    }

    @objc private func joystickDidConnect(notification: NSNotification) {
        if let controller = notification.object as? GCController {
            addGamepad(controller: controller)
        }
    }

    @objc private func joystickDidDisconnect(notification: NSNotification) {
        if let controller = notification.object as? GCController {
            removeGamepad(controller: controller)
        }
    }

    func gamepad(for id: Int) -> ConnectedGamepad? {
        gamepads.first { $0.id == id }
    }

    private func addGamepad(controller: GCController) {
        guard let gamepad = controller.extendedGamepad else {
            return
        }
        guard !gamepads.contains(where: { $0.controller === controller }) else {
            return
        }

        let gamepadId = nextId
        nextId += 1
        gamepads.append(
            ConnectedGamepad(id: gamepadId, controller: controller, gamepad: gamepad)
        )
        updatePlayerIndices()

        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            self?.listener?(gamepadId, gamepad, element)
        }

        connectionListener?(gamepadId, controller, true)
    }

    private func removeGamepad(controller: GCController) {
        // The controller is matched by identity rather than by its profile,
        // because `GCController.extendedGamepad` is no longer guaranteed to
        // resolve once the controller has disconnected.
        let removed = gamepads.filter { $0.controller === controller }
        for entry in removed {
            entry.gamepad.valueChangedHandler = nil
        }
        gamepads.removeAll(where: { $0.controller === controller })
        updatePlayerIndices()

        for entry in removed {
            connectionListener?(entry.id, entry.controller, false)
        }
    }

    private func updatePlayerIndices() {
        for (index, entry) in gamepads.enumerated() {
            entry.controller.playerIndex = toPlayerIndex(index: index)
        }
    }

    private func toPlayerIndex(index: Int) -> GCControllerPlayerIndex {
        switch index {
        case 0:
            return GCControllerPlayerIndex.index1
        case 1:
            return GCControllerPlayerIndex.index2
        case 2:
            return GCControllerPlayerIndex.index3
        case 3:
            return GCControllerPlayerIndex.index4
        default:
            return GCControllerPlayerIndex.indexUnset
        }
    }
}
