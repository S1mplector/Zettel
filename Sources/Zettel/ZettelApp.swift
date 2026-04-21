import AppKit
import SwiftUI
import ZettelKit

@main
struct ZettelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = NodeStore()

    var body: some Scene {
        WindowGroup("Zettel", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1100, height: 720)

        MenuBarExtra("Zettel", systemImage: AppVisualIdentity.symbolName) {
            MenuBarExtraContent(store: store)
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarExtraContent: View {
    @ObservedObject var store: NodeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Zettel") {
            openMainWindow()
        }

        Button("New Root Node") {
            _ = store.addRootNode()
            openMainWindow()
        }

        Divider()

        Button("Settings") {
            AppWindowController.openSettings()
        }

        Divider()

        Button("Quit Zettel") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
