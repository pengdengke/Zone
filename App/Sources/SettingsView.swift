import AppKit
import SwiftUI
import ZoneCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(model.strings.languageSectionTitle) {
                Picker(model.strings.languagePickerTitle, selection: Binding(
                    get: { model.settings.language },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(model.strings.languageOptionTitle(language)).tag(language)
                    }
                }
            }

            Section(model.strings.connectedDeviceSectionTitle) {
                Picker(model.strings.useThisTokenLabel, selection: Binding(
                    get: { model.settings.selectedDevice?.stableID ?? "" },
                    set: {
                        if $0.isEmpty {
                            model.clearSelectedDevice()
                        } else {
                            model.selectConnectedDevice(stableID: $0)
                        }
                    }
                )) {
                    Text(model.strings.noneOptionTitle).tag("")
                    ForEach(model.connectedDevices) { device in
                        Text(device.displayName).tag(device.stableID)
                    }
                }

                Button(model.strings.refreshConnectedDevicesButtonTitle) {
                    model.refreshConnectedDevices()
                }

                if model.connectedDevices.isEmpty {
                    Text(model.strings.connectedDevicesEmptyHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.settings.selectedDevice != nil, model.latestRSSIText == "--" {
                    Text(model.strings.liveSignalHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(model.strings.thresholdsSectionTitle) {
                Stepper(value: Binding(
                    get: { model.settings.lockThreshold },
                    set: { model.updateLockThreshold($0) }
                ), in: -100 ... -40) {
                    Text(model.strings.lockBelowTitle(model.settings.lockThreshold))
                }

                Stepper(value: Binding(
                    get: { model.settings.wakeThreshold },
                    set: { model.updateWakeThreshold($0) }
                ), in: -80 ... -20) {
                    Text(model.strings.wakeAboveTitle(model.settings.wakeThreshold))
                }

                Stepper(value: Binding(
                    get: { Int(model.settings.signalLossTimeout) },
                    set: { model.updateSignalLossTimeout(Double($0)) }
                ), in: 3 ... 30) {
                    Text(model.strings.signalLossTimeoutTitle(Int(model.settings.signalLossTimeout)))
                }

                Stepper(value: Binding(
                    get: { model.settings.slidingWindowSize },
                    set: { model.updateSlidingWindowSize($0) }
                ), in: 3 ... 10) {
                    Text(model.strings.slidingWindowTitle(model.settings.slidingWindowSize))
                }
            }

            Section(model.strings.permissionsAndStartupSectionTitle) {
                Text(model.strings.bluetoothAccessTitle(status: model.bluetoothPermissionStatusText))
                Text(model.strings.accessibilityTitle(status: model.accessibilityStatusText))
                Text(model.strings.loginItemTitle(status: model.loginItemStatusText))

                if model.isBluetoothAccessReady == false {
                    Text(model.strings.bluetoothPermissionHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if model.isAccessibilityReady == false {
                    Text(model.strings.accessibilityPermissionHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(model.strings.requestAccessibilityAccessButtonTitle) {
                        model.requestAccessibilityAccess()
                    }
                }

                Toggle(
                    model.strings.launchAtLoginTitle,
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }

            Section(model.strings.diagnosticsSectionTitle) {
                DiagnosticsView(
                    messages: model.diagnostics,
                    emptyStateText: model.strings.noDiagnosticsYetText
                )
            }
        }
        .padding(16)
        .onAppear {
            model.refreshConnectedDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshConnectedDevices()
        }
    }
}
