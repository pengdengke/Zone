import AppKit
import SwiftUI

@main
struct ZoneApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Zone", systemImage: model.menuBarSymbol) {
            StatusMenuContent(model: model)
        }

        Window("Zone Settings", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 480, minHeight: 560)
        }
    }
}
