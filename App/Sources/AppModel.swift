import Combine
import Foundation
import ZoneCore

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: ZoneSettings = .default
    @Published var connectedDevices: [SelectedDevice] = []
    @Published var statusLine = "Not Configured"
    @Published var latestRSSIText = "--"
    @Published var diagnostics: [String] = ["Zone is ready to be configured."]

    var menuBarSymbol: String {
        settings.selectedDevice == nil ? "dot.scope" : "lock.shield"
    }

    func pauseMonitoring() {}
    func resumeMonitoring() {}
    func lockNow() {}
    func wakeDisplayNow() {}
}
