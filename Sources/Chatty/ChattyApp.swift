import SwiftUI
import AppKit

@main
struct ChattyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Chatty") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

/// Without this, a binary launched outside a real .app bundle stays an
/// accessory/background process: the window shows but can't become key, so
/// the text field never receives keystrokes. Promote to a regular, frontmost
/// app on launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
