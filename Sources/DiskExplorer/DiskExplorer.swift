import SwiftUI

@main
struct DiskExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1020, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
        }
    }
}
