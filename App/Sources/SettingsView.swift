import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Connected Device") {
                Picker("Use this token", selection: Binding(
                    get: { model.settings.selectedDevice?.stableID ?? "" },
                    set: { model.selectConnectedDevice(stableID: $0) }
                )) {
                    Text("None").tag("")
                    ForEach(model.connectedDevices) { device in
                        Text(device.displayName).tag(device.stableID)
                    }
                }

                Button("Refresh Connected Devices") {
                    model.refreshConnectedDevices()
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
        .onAppear {
            model.refreshConnectedDevices()
        }
    }
}
