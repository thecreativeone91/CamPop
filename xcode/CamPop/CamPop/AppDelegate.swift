import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var cameraController: CameraController!
    var webServer: WebhookServer!
    var settingsWindow: NSWindow?
    var settingsWindowController: NSWindowController?
    @objc dynamic var isArmed: Bool = UserDefaults.standard.bool(forKey: "isArmed") {
        didSet {
            UserDefaults.standard.set(isArmed, forKey: "isArmed")
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // Add this line
        setupStatusBar()
        cameraController = CameraController()
        webServer = WebhookServer()
        webServer.onWebhookReceived = { [weak self] in
            guard let self = self, self.isArmed else { return }
            self.cameraController.showCamera()
        }
        
        // Add observer for arm toggle updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateArmToggle),
            name: NSNotification.Name("UpdateArmToggle"),
            object: nil
        )
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "CamPop")
        }
        
        let menu = NSMenu()
        
        // Replace the custom NSSwitch with a proper menu item toggle
        let armMenuItem = NSMenuItem(title: "Armed", action: #selector(toggleArmed(_:)), keyEquivalent: "")
        armMenuItem.state = isArmed ? .on : .off
        menu.addItem(armMenuItem)
        
        menu.addItem(withTitle: "Show Camera", action: #selector(showCamera), keyEquivalent: "s")
        menu.addItem(withTitle: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        statusBarItem.menu = menu
    }
    
    @objc func toggleArmed(_ sender: NSMenuItem) {
        isArmed = !isArmed
        sender.state = isArmed ? .on : .off
    }
    
    @objc private func updateArmToggle() {
        isArmed = UserDefaults.standard.bool(forKey: "isArmed")
        if let menu = statusBarItem.menu,
           let armMenuItem = menu.items.first {
            armMenuItem.state = isArmed ? .on : .off
        }
    }
    
    @objc func showCamera() {
        cameraController.showCamera()
    }
    
    @objc func showSettings() {
        if settingsWindowController == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hostingController
            window.title = "Settings"
            window.center()
            
            settingsWindowController = NSWindowController(window: window)
        }
        
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}