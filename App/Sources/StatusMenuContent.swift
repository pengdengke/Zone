import SwiftUI

struct StatusMenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.localizedStatusLine)
                .font(.headline)

            Text("\(model.strings.rssiLabelTitle): \(model.latestRSSIText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(model.strings.deviceLabelTitle): \(model.settings.selectedDevice?.displayName ?? model.strings.noneOptionTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button(model.strings.openSettingsButtonTitle) {
                openWindow(id: "settings")
            }

            if model.isMonitoringPaused {
                Button(model.strings.resumeMonitoringButtonTitle) {
                    model.resumeMonitoring()
                }
                .disabled(model.settings.selectedDevice == nil)
            } else {
                Button(model.strings.pauseMonitoringButtonTitle) {
                    model.pauseMonitoring()
                }
                .disabled(model.settings.selectedDevice == nil)
            }

            Button(model.strings.lockNowButtonTitle) {
                model.lockNow()
            }

            Button(model.strings.wakeDisplayNowButtonTitle) {
                model.wakeDisplayNow()
            }

            Divider()

            Button(model.strings.quitButtonTitle) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
