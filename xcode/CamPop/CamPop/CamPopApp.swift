import SwiftUI

@main
struct CamPopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // Remove the default menu bar items
            CommandGroup(replacing: .appInfo) {}
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(replacing: .newItem) {}
        }
    }
}