import SwiftUI
import AppKit
import Carbon

@main
struct TranslitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var keyCode: Int {
        didSet { UserDefaults.standard.set(keyCode, forKey: "keyCode"); updateShortcut() }
    }
    @Published var modifiers: Int {
        didSet { UserDefaults.standard.set(modifiers, forKey: "modifiers"); updateShortcut() }
    }
    @Published var isRecording = false

    init() {
        self.keyCode = UserDefaults.standard.object(forKey: "keyCode") == nil ? 17 : UserDefaults.standard.integer(forKey: "keyCode")
        self.modifiers = UserDefaults.standard.object(forKey: "modifiers") == nil ? (cmdKey | optionKey) : UserDefaults.standard.integer(forKey: "modifiers")
    }
    
    func updateShortcut() {
        debugLog("AppState: Updating shortcut preference...")
        if let delegate = NSApp.delegate as? AppDelegate {
            GlobalShortcutManager.shared.register(
                keyCode: UInt32(keyCode),
                modifiers: UInt32(modifiers),
                target: delegate,
                action: #selector(AppDelegate.toggleTranslit)
            )
        }
    }
}

class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        debugLog("AppDelegate: App Launching...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        setupMenu()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleNotification), name: Notification.Name("TranslitToggled"), object: nil)
        
        let trusted = checkPermissions()
        debugLog("AppDelegate: Initial permission check = \(trusted)")
        
        EventTapManager.shared.start()
        AppState.shared.updateShortcut()
    }
    
    @objc func handleToggleNotification() {
        updateStatusIcon()
        updateMenuState()
    }
    
    func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Transliteration", action: #selector(toggleTranslit), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        updateMenuState()
    }
    
    @objc func openSettings() {
        debugLog("AppDelegate: Opening Settings Window")
        NSApp.activate(ignoringOtherApps: true)
        
        if settingsWindow == nil {
            let window = SettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("TranslitSettings")
            window.title = "Translit Settings"
            window.contentView = NSHostingView(rootView: SettingsView(appState: AppState.shared))
            window.isReleasedWhenClosed = false
            window.level = .floating
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func updateMenuState() {
        let title = EventTapManager.shared.isEnabled ? "Disable" : "Enable"
        statusItem?.menu?.items.first?.title = title
    }

    func updateStatusIcon() {
        if let button = statusItem?.button {
            let name = EventTapManager.shared.isEnabled ? "t.circle.fill" : "t.circle"
            button.image = NSImage(systemSymbolName: name, accessibilityDescription: "Translit")
        }
    }
    
    @objc func toggleTranslit() {
        EventTapManager.shared.isEnabled.toggle()
        updateStatusIcon()
        updateMenuState()
        debugLog("AppDelegate: Toggled Transliteration. New State: \(EventTapManager.shared.isEnabled)")
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            MappingView()
                .tabItem {
                    Label("Mapping", systemImage: "text.book.closed")
                }
        }
        .frame(width: 450, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Translit Settings")
                .font(.headline)
            
            VStack(spacing: 10) {
                Text("Global Hotkey:")
                
                if appState.isRecording {
                    Text("Press keys... (Enter to Save, Esc to Cancel)")
                        .font(.callout)
                        .foregroundColor(.blue)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2))
                } else {
                    Button(action: { 
                        appState.isRecording = true 
                        NSApp.activate(ignoringOtherApps: true)
                    }) {
                        Text(shortcutString(keyCode: appState.keyCode, modifiers: appState.modifiers))
                            .font(.title2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text("Type in any app to see Cyrillic output.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .background(KeyRecordingView(isRecording: $appState.isRecording, keyCode: $appState.keyCode, modifiers: $appState.modifiers))
    }
    
    func shortcutString(keyCode: Int, modifiers: Int) -> String {
        var str = ""
        if modifiers & cmdKey != 0 { str += "⌘ " }
        if modifiers & optionKey != 0 { str += "⌥ " }
        if modifiers & shiftKey != 0 { str += "⇧ " }
        if modifiers & controlKey != 0 { str += "⌃ " }
        
        if let char = specialKeyMap[keyCode] {
            str += char
        } else {
             if keyCode == 17 { str += "T" }
             else if keyCode == 0 { str += "A" }
             else if keyCode == 1 { str += "S" }
             else if keyCode == 13 { str += "W" }
             else if keyCode == 2 { str += "D" }
             else { str += "Key\(keyCode)" }
        }
        return str
    }
    
    let specialKeyMap: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

struct MappingView: View {
    let mapping = Transliterater.mapping.sorted { $0.0 < $1.0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mapping Table")
                .font(.headline)
                .padding(.top)
                .padding(.horizontal)
            
            List {
                HStack {
                    Text("Latin")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Cyrillic")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
                
                ForEach(mapping, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.1)
                            .font(.system(.body, design: .serif))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct KeyRecordingView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    
    class Coordinator: NSObject {
        var parent: KeyRecordingView
        var monitor: Any?
        
        init(_ parent: KeyRecordingView) {
            self.parent = parent
        }
        
        func startMonitoring() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if !self.parent.isRecording { return event }
                
                debugLog("KeyRecordingView: Captured KeyCode: \(event.keyCode)")
                
                if event.keyCode == 53 { self.parent.isRecording = false; return nil }
                if event.keyCode == 36 { self.parent.isRecording = false; return nil }
                
                self.parent.keyCode = Int(event.keyCode)
                self.parent.modifiers = Int(event.modifierFlags.carbonModifiers)
                return nil
            }
        }
        
        func stopMonitoring() {
            if let monitor = monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSView { 
        let view = NSView()
        view.allowedTouchTypes = .direct
        return view 
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording { 
             if context.coordinator.monitor == nil { context.coordinator.startMonitoring() }
        } else { 
             context.coordinator.stopMonitoring() 
        }
    }
}

extension NSEvent.ModifierFlags {
    var carbonModifiers: Int {
        var res: Int = 0
        if contains(.command) { res |= cmdKey }
        if contains(.option) { res |= optionKey }
        if contains(.shift) { res |= shiftKey }
        if contains(.control) { res |= controlKey }
        return res
    }
}
