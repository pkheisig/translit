import Cocoa
import Carbon

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    private var monitor: Any?
    private var target: Any?
    private var action: Selector?
    private var currentKeyCode: UInt16 = 0
    private var currentModifiers: NSEvent.ModifierFlags = []

    func register(keyCode: UInt32, modifiers: UInt32, target: Any, action: Selector) {
        removeMonitor()
        
        self.target = target
        self.action = action
        self.currentKeyCode = UInt16(keyCode)
        self.currentModifiers = carbonModifiersToFlags(modifiers)
        
        debugLog("GlobalShortcutManager: Registering hotkey. KeyCode: \(keyCode), Modifiers: \(currentModifiers)")
        
        // We use addGlobalMonitorForEvents.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Filter out common typing to avoid log spam, but log suspicious matches
            // Actually, for "very thorough logging", let's log everything for a bit
            // debugLog("GlobalMonitor: KeyDown observed. Code: \(event.keyCode), Mods: \(event.modifierFlags)") 
            self?.handleEvent(event)
        }
        
        // Also add local monitor so it works when our settings window is focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            debugLog("LocalMonitor: KeyDown observed. Code: \(event.keyCode)")
            self?.handleEvent(event)
            return event
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        // Check key code
        guard event.keyCode == currentKeyCode else { return }
        
        // Check modifiers. We ignore CapsLock/NumLock by masking.
        let requiredFlags = currentModifiers
        let eventFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        if eventFlags == requiredFlags {
            debugLog("GlobalShortcutManager: HOTKEY MATCH! Triggering action.")
            if let target = target as? NSObject, let action = action {
                target.perform(action)
            } else {
                debugLog("GlobalShortcutManager: Target or Action is nil!")
            }
        } else {
             debugLog("GlobalShortcutManager: Key match (\(event.keyCode)) but modifiers mismatch. Got: \(eventFlags), Wanted: \(requiredFlags)")
        }
    }

    func removeMonitor() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            debugLog("GlobalShortcutManager: Monitor removed.")
        }
    }
    
    private func carbonModifiersToFlags(_ carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if (carbon & UInt32(cmdKey)) != 0 { flags.insert(.command) }
        if (carbon & UInt32(optionKey)) != 0 { flags.insert(.option) }
        if (carbon & UInt32(controlKey)) != 0 { flags.insert(.control) }
        if (carbon & UInt32(shiftKey)) != 0 { flags.insert(.shift) }
        return flags
    }
}