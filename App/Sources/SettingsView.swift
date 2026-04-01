import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Connected Device") {
                Picker("Use this token", selection: Binding(
                    get: { model.settings.selectedDevice?.stableID ?? "" },
                    set: {
                        if $0.isEmpty {
                            model.clearSelectedDevice()
                        } else {
                            model.selectConnectedDevice(stableID: $0)
                        }
                    }
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
                Stepper("Lock below: \(model.settings.lockThreshold) dBm", value: Binding(
                    get: { model.settings.lockThreshold },
                    set: { model.updateLockThreshold($0) }
                ), in: -100 ... -40)

                Stepper("Wake above: \(model.settings.wakeThreshold) dBm", value: Binding(
                    get: { model.settings.wakeThreshold },
                    set: { model.updateWakeThreshold($0) }
                ), in: -80 ... -20)

                Stepper("Signal loss timeout: \(Int(model.settings.signalLossTimeout)) s", value: Binding(
                    get: { Int(model.settings.signalLossTimeout) },
                    set: { model.updateSignalLossTimeout(Double($0)) }
                ), in: 3 ... 30)

                Stepper("Sliding window: \(model.settings.slidingWindowSize)", value: Binding(
                    get: { model.settings.slidingWindowSize },
                    set: { model.updateSlidingWindowSize($0) }
                ), in: 3 ... 10)
            }

            Section("Permissions & Startup") {
                Text("Bluetooth access: \(model.bluetoothPermissionStatusText)")
                Text("Accessibility: \(model.accessibilityStatusText)")
                Text("Login item: \(model.loginItemStatusText)")

                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
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
