# Zone macOS RSSI Boundary Design

## Summary

Zone is a macOS menu bar application that treats a selected Bluetooth device as a proximity token. The app monitors the token's signal strength while the device remains connected to the Mac, then locks the Mac when the signal becomes weak or disappears and wakes the display back to the login screen when the signal becomes strong again.

This first version is intentionally narrow:

- Only the macOS application is in scope.
- The phone or token device must not require a companion app.
- The monitored device must already be connected through the system Bluetooth stack.
- The boundary is defined by RSSI signal strength, not by simple paired/connected state alone.
- Returning only wakes the display to the login screen. It does not bypass authentication.

## Product Goals

- Make leaving the desk feel automatic by locking the Mac when the token moves away.
- Make returning feel quick by waking the display as the token comes back into range.
- Keep the system safe by never attempting to bypass the lock screen.
- Keep setup simple by selecting from devices already connected in macOS.

## Non-Goals

- No mobile app development.
- No support guarantee for every phone model or Bluetooth profile.
- No attempt to infer physical distance when the selected device is not connected.
- No direct desktop unlock, password entry, or biometric bypass.
- No multi-device presence rules in the first version.

## Key Assumptions

- The chosen token device can stay connected to the Mac long enough for repeated RSSI reads to be meaningful.
- macOS can observe the selected device through `IOBluetoothDevice`, including connection state and RSSI while connected.
- A lock action may require Accessibility permission if the final implementation uses synthesized system shortcuts.
- Wake behavior can be implemented as a user-activity style display wake, not a full unlock.

## User Experience

### First Launch

On first launch, the app opens a settings window and asks the user to:

1. Grant Bluetooth access if required.
2. Choose one device from the list of currently connected Bluetooth devices.
3. Review or keep the default threshold values.
4. Optionally enable launch at login.

Once configured, the app moves into normal background operation from the menu bar.

### Menu Bar Experience

The menu bar item is the primary UI. It shows current operating status and exposes fast controls.

Menu contents:

- Current state: `Not Configured`, `Monitoring`, `Locked`, `Signal Weak`, `Device Disconnected`, or `Paused`
- Selected device name
- Latest RSSI and averaged RSSI when available
- `Pause Monitoring`
- `Resume Monitoring`
- `Lock Now`
- `Wake Display Now`
- `Open Settings`
- `Quit`

### Settings Window

The settings window contains:

- Connected-device picker
- Lock threshold RSSI
- Wake threshold RSSI
- Signal-loss timeout in seconds
- Sliding-window size
- Launch-at-login toggle
- Permission status for Bluetooth, Accessibility, and login item approval
- Diagnostics panel with recent samples and recent actions

## Architecture

The app is a native macOS app built with Swift and SwiftUI, using AppKit integration where menu bar or system APIs require it.

The design is split into focused units:

- `AppShell`
  Owns app lifecycle, menu bar setup, settings window presentation, and launch-at-login integration.
- `BluetoothDeviceRepository`
  Enumerates currently connected Bluetooth devices, resolves the stored token device, and emits connection changes.
- `RSSIMonitor`
  Polls the selected connected device at a fixed interval, captures RSSI samples, tracks missing-signal time, and publishes smoothed signal data.
- `BoundaryEngine`
  Implements the state machine and threshold logic. It is pure business logic and has no direct dependency on macOS UI APIs.
- `SystemActionService`
  Performs lock-screen and wake-display actions and reports failures.
- `SettingsStore`
  Persists the selected device identifier and all user-adjustable thresholds.
- `DiagnosticsStore`
  Retains recent samples, transitions, and action outcomes for debugging and calibration.

## Device Selection Model

The device picker only shows devices that are currently connected through the system Bluetooth stack.

The stored identity should prefer a stable device identifier exposed by the platform. If the platform identity is not stable enough across reconnects, the app should store a fallback tuple that includes:

- Bluetooth address or platform identifier
- Human-readable name at selection time
- Device class if available

At runtime, the repository attempts to resolve the configured token device in this order:

1. Exact stable identifier match
2. Fallback Bluetooth address match
3. Name plus device-class fallback, used only as a last resort and surfaced in diagnostics

If the token device cannot be resolved, monitoring remains paused and the UI explains why.

## Core State Machine

The application maintains three states:

- `UNKNOWN`
  Initial state during startup, permission changes, or device rebind. No lock or wake action is emitted here.
- `UNLOCKED`
  The app believes the user is present. It will only transition out when signal becomes weak or disappears.
- `LOCKED`
  The app has already triggered a lock. It will only transition out when signal becomes confidently strong again.

State transitions:

- `UNKNOWN -> UNLOCKED`
  When enough signal data exists to conclude the token is present.
- `UNKNOWN -> LOCKED`
  Never on startup. The app should not lock immediately after launch without a stable observation window.
- `UNLOCKED -> LOCKED`
  When averaged RSSI falls below the lock threshold or signal is lost for the configured timeout.
- `LOCKED -> UNLOCKED`
  When averaged RSSI rises above the wake threshold.

Actions are edge-triggered. Reaching the same condition repeatedly must not cause repeated lock or wake commands.

## Sampling and Filtering

Default sampling behavior:

- Poll interval: 1 second
- Sliding window size: 5 samples
- Signal-loss timeout: 10 seconds

Sampling rules:

- If the device is connected and RSSI is readable, push the latest RSSI into the fixed-size window.
- If the device is connected but RSSI cannot be read for one cycle, record a transient read failure and keep the existing window.
- If RSSI remains unreadable or the device disconnects, increment missing-signal duration.
- Once missing-signal duration reaches the configured timeout, emit a `signalLost` condition.

Smoothed value:

- `averageRSSI = sum(window) / window.count`
- Decisions use the averaged RSSI, not the latest single sample.

## Threshold Rules

Default thresholds:

- Lock threshold: `-85 dBm`
- Wake threshold: `-55 dBm`

Rules:

- Lock when current state is `UNLOCKED` and either:
  - averaged RSSI is below `-85 dBm`, or
  - signal is lost for at least 10 seconds
- Wake the display when current state is `LOCKED` and averaged RSSI is above `-55 dBm`

The gap between `-85` and `-55` creates hysteresis so the app does not flap near a single boundary.

## Lock and Wake Behavior

### Lock

Preferred behavior is immediate lock to the login screen.

Implementation priority:

1. Use a stable system lock mechanism exposed to normal macOS apps.
2. If public APIs are insufficient, fall back to synthesizing the standard lock shortcut `Control + Command + Q`.

The implementation must not put the Mac to sleep as a substitute for locking because sleep behavior varies by machine and does not guarantee the intended login-screen experience.

### Wake

Wake means making the display active again so the login screen is visible. It does not unlock the session.

Preferred behavior:

- Use a power-management user-activity style API to wake or re-activate the display.
- If the machine is deeply asleep rather than simply display-sleeping, wake is best-effort and the diagnostics panel should record the outcome.

## Permissions and System Integration

The app must surface permission state clearly and never fail silently.

Expected permissions and integrations:

- Bluetooth access
  Required for device discovery, monitoring, and RSSI reads.
- Accessibility permission
  Required only if the chosen lock implementation uses a synthesized system shortcut.
- Login item registration
  Implemented with `SMAppService.mainAppService` for launch-at-login behavior.

The settings UI should include direct guidance for resolving missing permissions.

## Error Handling

### Recoverable Conditions

- One-off RSSI read failure
- Temporary Bluetooth reset
- Brief disconnect followed by reconnect before loss timeout

These conditions should only affect diagnostics and monitoring state. They should not trigger modal errors.

### User-Action Conditions

- Bluetooth unavailable or unauthorized
- Accessibility permission missing when lock action requires it
- Selected device no longer appears as a connected device
- Lock or wake command returns failure

These conditions should be visible in both menu bar status and settings diagnostics.

## Persistence

Persist the following values locally:

- Selected device identity
- Lock threshold
- Wake threshold
- Sliding-window size
- Signal-loss timeout
- Launch-at-login preference
- Last known diagnostics metadata that helps the UI explain current status

Persistence can start with `UserDefaults` and move to a more structured store only if needed.

## Testing Strategy

### Unit Tests

Unit tests should cover the pure `BoundaryEngine` logic:

- Sliding-window averaging
- Hysteresis between lock and wake thresholds
- Signal-loss timeout behavior
- No repeated lock while already `LOCKED`
- No repeated wake while already `UNLOCKED`
- Safe startup behavior from `UNKNOWN`

### Integration Tests

Use mocked device and system-action services to verify:

- RSSI samples flow into the boundary engine correctly
- Disconnect and reconnect paths trigger the right transitions
- Settings changes take effect without app restart

### Manual Verification

Manual testing on a real Mac is required for:

- Connected-device selection
- Live RSSI monitoring
- Lock action success
- Wake-display success
- Launch-at-login registration
- Permission prompts and recovery messaging

## Delivery Plan Shape

The implementation should proceed in stages:

1. Scaffold native macOS menu bar app shell
2. Add settings storage and settings UI
3. Add connected Bluetooth device enumeration and selection
4. Add RSSI polling and diagnostics
5. Add pure boundary engine with tests
6. Integrate lock and wake actions
7. Add login item support
8. Polish packaging metadata and produce a DMG

## Packaging

The release target is a signed macOS `.app` bundled into a `.dmg`.

Packaging work includes:

- Stable bundle identifier
- App icon
- Usage descriptions required by macOS
- Release build configuration
- Archive and export process
- DMG creation workflow

`master` remains the packaging-oriented branch, while feature development happens on `develop`.

## Risks and Mitigations

- Some phones may not maintain a Bluetooth connection that yields steady RSSI.
  Mitigation: clearly position first-version compatibility around continuously connected devices and expose diagnostics.
- RSSI may vary significantly by pocket placement, body orientation, or desk layout.
  Mitigation: use a sliding average plus separate lock and wake thresholds, and expose tuning controls.
- Wake behavior may differ depending on whether the Mac is display-sleeping or fully sleeping.
  Mitigation: define wake as best-effort display activation and document the limitation.
- Lock implementation may need Accessibility permission.
  Mitigation: present the reason clearly and keep the permission optional until lock is first used.

## Open Compatibility Note

This design intentionally optimizes for a strong first macOS release rather than universal Bluetooth compatibility. Devices that do not maintain a suitable connection or do not expose meaningful RSSI while connected may not behave well in the first version. That is an accepted limitation for v1.
