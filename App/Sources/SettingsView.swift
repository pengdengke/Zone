import AppKit
import SwiftUI
import ZoneCore

struct SettingsView: View {
    private static let labelColumnWidth: CGFloat = 180
    private static let rowSpacing: CGFloat = 12

    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section(model.strings.languageSectionTitle) {
                controlRow(model.strings.languagePickerTitle) {
                    Picker("", selection: Binding(
                        get: { model.settings.language },
                        set: { model.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(model.strings.languageOptionTitle(language)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section(model.strings.versionSectionTitle) {
                statusRow(model.strings.currentVersionLabelTitle, status: model.currentVersionText)
                statusRow(model.strings.latestReleaseLabelTitle, status: model.latestReleaseVersionText)
                statusRow(model.strings.releasePublishedAtLabelTitle, status: model.latestReleasePublishedAtText)
                statusRow(model.strings.updateStatusLabelTitle, status: model.updateStatusText)

                detailRow {
                    HStack(spacing: 12) {
                        Button(model.strings.checkForUpdatesButtonTitle) {
                            Task {
                                await model.checkForUpdates()
                            }
                        }
                        .disabled(model.isCheckingForUpdates)

                        Button(model.strings.openLatestReleaseButtonTitle) {
                            model.openLatestReleasePage()
                        }
                        .disabled(model.canOpenLatestReleasePage == false)
                    }
                }
            }

            Section(model.strings.connectedDeviceSectionTitle) {
                controlRow(model.strings.useThisTokenLabel) {
                    Picker("", selection: Binding(
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
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                detailRow {
                    Button(model.strings.refreshConnectedDevicesButtonTitle) {
                        model.refreshConnectedDevices()
                    }
                }

                if model.connectedDevices.isEmpty {
                    detailHint(model.strings.connectedDevicesEmptyHint)
                } else if model.settings.selectedDevice != nil, model.latestRSSIText == "--" {
                    detailHint(model.strings.liveSignalHint)
                }
            }

            Section(model.strings.thresholdsSectionTitle) {
                controlRow(model.strings.lockBelowLabelTitle) {
                    stepperValueRow(model.strings.lockThresholdValueTitle(model.settings.lockThreshold)) {
                        Stepper(value: Binding(
                            get: { model.settings.lockThreshold },
                            set: { model.updateLockThreshold($0) }
                        ), in: -100 ... -40) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }

                controlRow(model.strings.wakeAboveLabelTitle) {
                    stepperValueRow(model.strings.wakeThresholdValueTitle(model.settings.wakeThreshold)) {
                        Stepper(value: Binding(
                            get: { model.settings.wakeThreshold },
                            set: { model.updateWakeThreshold($0) }
                        ), in: -80 ... -20) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }

                controlRow(model.strings.signalLossTimeoutLabelTitle) {
                    stepperValueRow(model.strings.signalLossTimeoutValueTitle(Int(model.settings.signalLossTimeout))) {
                        Stepper(value: Binding(
                            get: { Int(model.settings.signalLossTimeout) },
                            set: { model.updateSignalLossTimeout(Double($0)) }
                        ), in: 3 ... 30) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }

                controlRow(model.strings.slidingWindowLabelTitle) {
                    stepperValueRow(model.strings.slidingWindowValueTitle(model.settings.slidingWindowSize)) {
                        Stepper(value: Binding(
                            get: { model.settings.slidingWindowSize },
                            set: { model.updateSlidingWindowSize($0) }
                        ), in: 3 ... 10) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }
                }
            }

            Section(model.strings.permissionsAndStartupSectionTitle) {
                statusRow(model.strings.bluetoothAccessLabelTitle, status: model.bluetoothPermissionStatusText)
                statusRow(model.strings.accessibilityLabelTitle, status: model.accessibilityStatusText)
                statusRow(model.strings.loginItemLabelTitle, status: model.loginItemStatusText)

                if model.isBluetoothAccessReady == false {
                    detailHint(model.strings.bluetoothPermissionHelpText)
                }

                if model.isAccessibilityReady == false {
                    detailHint(model.strings.accessibilityPermissionHelpText)

                    detailRow {
                        Button(model.strings.requestAccessibilityAccessButtonTitle) {
                            model.requestAccessibilityAccess()
                        }
                    }
                }

                controlRow(model.strings.launchAtLoginTitle) {
                    Toggle("", isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                }
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

    private func controlRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: Self.rowSpacing) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: Self.labelColumnWidth, alignment: .trailing)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: Self.rowSpacing) {
            Spacer()
                .frame(width: Self.labelColumnWidth)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailHint(_ text: String) -> some View {
        detailRow {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusRow(_ label: String, status: String) -> some View {
        controlRow(label) {
            Text(model.strings.localizedSystemStatus(status))
        }
    }

    private func stepperValueRow<Content: View>(
        _ valueText: String,
        @ViewBuilder stepper: () -> Content
    ) -> some View {
        HStack(spacing: Self.rowSpacing) {
            Text(valueText)
                .monospacedDigit()
                .frame(minWidth: 84, alignment: .leading)

            stepper()
        }
    }
}
