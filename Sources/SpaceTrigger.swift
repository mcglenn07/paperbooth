import AppKit

// One physical press produces at most one trigger, even if it is held across
// the end of a countdown. A fresh key-down is required after losing focus.
struct SpacePressGate {
    private(set) var isDown = false
    mutating func press(isRepeat: Bool) -> Bool {
        let fire = !isDown && !isRepeat
        isDown = true
        return fire
    }
    mutating func release() { isDown = false }
}

@MainActor
final class SpaceTrigger {
    weak var model: BoothModel?
    private var monitor: Any?
    private var deactivateObserver: NSObjectProtocol?
    private var gate = SpacePressGate()
    private var consumedPress = false

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
        deactivateObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                                    object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.gate.release(); self?.consumedPress = false }
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.keyCode == 49 else { return event }
        if event.type == .keyUp {
            let consumed = consumedPress
            gate.release()
            consumedPress = false
            return consumed ? nil : event
        }
        guard let model, model.manualMode, NSApp.isActive,
              event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
              !model.showSettings, model.discardAction == nil, model.error == nil,
              NSApp.modalWindow == nil, let window = NSApp.keyWindow,
              window.attachedSheet == nil,
              (window is GuestWindow || window.title == "Paperbooth"),
              !(window.firstResponder is NSTextView), !(window.firstResponder is NSTextField) else {
            // Remember that this press began outside capture controls; don't turn
            // its auto-repeat into a shutter if focus moves while it is held.
            _ = gate.press(isRepeat: event.isARepeat)
            return event
        }
        let fire = gate.press(isRepeat: event.isARepeat)
        consumedPress = true
        if fire { model.triggerManualAction() }
        // Consume to prevent an additional focused-button action. After review,
        // a separate key release and press is required to start the next photo.
        return nil
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
    }
}
