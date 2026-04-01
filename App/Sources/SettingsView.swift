import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            if let setupBanner = model.setupBanner {
                Section {
                    SetupBannerCard(
                        banner: setupBanner,
                        showsAccessibilityAction: model.showsAccessibilityAccessButton,
                        accessibilityActionTitle: model.accessibilityRequestButtonTitle,
                        requestAccessibilityAccess: model.requestAccessibilityAccess
                    )
                }
            }

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

                if model.connectedDevices.isEmpty {
                    Text("Zone only lists Bluetooth devices that macOS currently sees as connected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.settings.selectedDevice != nil, model.latestRSSIText == "--" {
                    Text("Zone still needs a live negative RSSI sample. If it stays --, reconnect the device or choose another connected device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

                if model.isBluetoothAccessReady == false {
                    Text("Bluetooth permission is required to read your connected device list and signal strength.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if model.isAccessibilityReady == false {
                    Text("Without Accessibility access, Zone cannot trigger macOS lock for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

private struct SetupBannerCard: View {
    let banner: SetupBanner
    let showsAccessibilityAction: Bool
    let accessibilityActionTitle: String
    let requestAccessibilityAccess: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: banner.symbolName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(banner.title)
                    .fontWeight(.medium)
                Text(banner.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showsAccessibilityAction {
                    Button(accessibilityActionTitle) {
                        requestAccessibilityAccess()
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
