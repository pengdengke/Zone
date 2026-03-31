import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Connected Device") {
                if model.connectedDevices.isEmpty {
                    Text("No connected Bluetooth device selected yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.connectedDevices) { device in
                        Text(device.displayName)
                    }
                }
            }

            Section("Thresholds") {
                Text("Lock below: \(model.settings.lockThreshold) dBm")
                Text("Wake above: \(model.settings.wakeThreshold) dBm")
                Text("Signal loss timeout: \(Int(model.settings.signalLossTimeout)) s")
                Text("Sliding window: \(model.settings.slidingWindowSize)")
            }

            Section("Diagnostics") {
                DiagnosticsView(messages: model.diagnostics)
            }
        }
        .padding(16)
    }
}
