import SwiftUI

struct StatusMenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.statusLine)
                .font(.headline)

            Text("RSSI: \(model.latestRSSIText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Device: \(model.settings.selectedDevice?.displayName ?? "None")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Settings") {
                openWindow(id: "settings")
            }

            if model.isMonitoringPaused {
                Button("Resume Monitoring") {
                    model.resumeMonitoring()
                }
                .disabled(model.settings.selectedDevice == nil)
            } else {
                Button("Pause Monitoring") {
                    model.pauseMonitoring()
                }
                .disabled(model.settings.selectedDevice == nil)
            }

            Button("Lock Now") {
                model.lockNow()
            }

            Button("Wake Display Now") {
                model.wakeDisplayNow()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
