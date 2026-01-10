import Foundation
import Cocoa
import Carbon

public func debugLog(_ message: String) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm:ss.SSS"
    let timestamp = dateFormatter.string(from: Date())
    let logMessage = "\(timestamp): \(message)\n"
    
    if let data = logMessage.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/translit_debug.log")
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: url)
        }
    }
}



class EventTapManager {
    static let shared = EventTapManager()
    var isEnabled = true
    private var eventTap: CFMachPort?
    private var typedBuffer = "" 
    
    func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        debugLog("EventTapManager: Permission Check = \(trusted)")
        return trusted
    }

    func start() {
        debugLog("EventTapManager: Requesting to start EventTap...")
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            debugLog("EventTapManager: CRITICAL FAILURE. Could not create Event Tap. Permissions likely denied.")
            return
        }
        
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        debugLog("EventTapManager: EventTap started and added to RunLoop.")
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Skip events we generated
        if event.getIntegerValueField(.eventSourceUserData) == 1337 {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Check for toggle hotkey FIRST (before isEnabled check)
        let appState = AppState.shared
        if Int(keyCode) == appState.keyCode {
            let hasCmd = flags.contains(.maskCommand)
            let hasOpt = flags.contains(.maskAlternate)
            let hasShift = flags.contains(.maskShift)
            let hasCtrl = flags.contains(.maskControl)
            
            let wantCmd = (appState.modifiers & cmdKey) != 0
            let wantOpt = (appState.modifiers & optionKey) != 0
            let wantShift = (appState.modifiers & shiftKey) != 0
            let wantCtrl = (appState.modifiers & controlKey) != 0
            
            if hasCmd == wantCmd && hasOpt == wantOpt && hasShift == wantShift && hasCtrl == wantCtrl {
                self.isEnabled.toggle()
                debugLog("EventTapManager: HOTKEY DETECTED! New state: \(self.isEnabled)")
                NotificationCenter.default.post(name: Notification.Name("TranslitToggled"), object: nil)
                return nil
            }
        }
        
        // Now check if transliteration is enabled
        if !isEnabled { 
            return Unmanaged.passRetained(event) 
        }
        
        debugLog("EventTapManager: KeyDown received. KeyCode: \(keyCode)")
        
        // Reset buffer on non-char keys
        if keyCode == kVK_Space || keyCode == kVK_Return || keyCode == kVK_Tab || keyCode == kVK_Escape || flags.contains(.maskCommand) {
            if !typedBuffer.isEmpty {
                debugLog("EventTapManager: Resetting buffer (was: '\(typedBuffer)'). Reason: Break key or Cmd.")
                typedBuffer = ""
            }
            return Unmanaged.passRetained(event)
        }
        
        if keyCode == kVK_Delete {
            if !typedBuffer.isEmpty { 
                typedBuffer.removeLast() 
                debugLog("EventTapManager: Backspace. Buffer now: '\(typedBuffer)'")
            }
            return Unmanaged.passRetained(event)
        }
        
        guard let chars = getCharacters(event: event), !chars.isEmpty else {
            debugLog("EventTapManager: No char data in event.")
            return Unmanaged.passRetained(event)
        }
        
        let newChar = chars
        let currentSequence = typedBuffer + newChar.lowercased()
        debugLog("EventTapManager: Processing sequence: '\(currentSequence)'")
        
        // Check for matches
        for (latin, cyrillic) in Transliterater.mapping {
            if currentSequence.hasSuffix(latin) {
                let isUppercase = newChar.first?.isUppercase ?? false
                let cyrillicChar = isUppercase ? cyrillic.uppercased() : cyrillic
                
                debugLog("EventTapManager: MATCH FOUND! '\(latin)' -> '\(cyrillicChar)'")
                
                if latin.count > 1 {
                    // Multi-char match
                    let backspacesNeeded = latin.count - 1
                    debugLog("EventTapManager: Multi-char match. Injecting \(backspacesNeeded) backspaces + '\(cyrillicChar)'")
                    sendBackspaces(count: backspacesNeeded)
                    sendString(cyrillicChar)
                    typedBuffer = currentSequence
                    return nil // Consume original event
                } else {
                    // Single char match
                    debugLog("EventTapManager: Single-char match. Modifying event in-place to '\(cyrillicChar)'")
                    modifyEvent(event, with: cyrillicChar)
                    typedBuffer = currentSequence
                    return Unmanaged.passRetained(event)
                }
            }
        }
        
        // No match found
        // Only block Latin letters not used in transliteration (w, x, q)
        let blockedChars = Set("wxq")
        let charLower = newChar.lowercased()
        
        if charLower.count == 1, let c = charLower.first, blockedChars.contains(c) {
            debugLog("EventTapManager: BLOCKED unused char: '\(newChar)'")
            return nil
        }
        
        // Pass through numbers, symbols, and valid letters that might start a sequence
        typedBuffer += charLower
        if typedBuffer.count > 10 { typedBuffer.removeFirst() }
        debugLog("EventTapManager: No match. Buffer updated: '\(typedBuffer)'")
        
        return Unmanaged.passRetained(event)
    }
    
    private func getCharacters(event: CGEvent) -> String? {
        var len = 0
        let maxLen = 4
        var chars = [UniChar](repeating: 0, count: maxLen)
        event.keyboardGetUnicodeString(maxStringLength: maxLen, actualStringLength: &len, unicodeString: &chars)
        if len > 0 {
            return String(utf16CodeUnits: chars, count: len)
        }
        return nil
    }
    
    private func modifyEvent(_ event: CGEvent, with string: String) {
        let utf16Chars = Array(string.utf16)
        event.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
    }
    
    private func sendBackspaces(count: Int) {
        for _ in 0..<count {
            postKey(keyCode: CGKeyCode(kVK_Delete), down: true)
            postKey(keyCode: CGKeyCode(kVK_Delete), down: false)
        }
    }
    
    private func sendString(_ string: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let utf16Chars = Array(string.utf16)
        
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        down?.setIntegerValueField(.eventSourceUserData, value: 1337)
        down?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        down?.post(tap: .cghidEventTap)
        
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        up?.setIntegerValueField(.eventSourceUserData, value: 1337)
        up?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        up?.post(tap: .cghidEventTap)
    }
    
    private func postKey(keyCode: CGKeyCode, down: Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down)
        event?.setIntegerValueField(.eventSourceUserData, value: 1337)
        event?.post(tap: .cghidEventTap)
    }
}
