# Zone

> Turn your trusted device into a Bluetooth boundary for your Mac.

Zone is a macOS menu bar app that reads Bluetooth RSSI from a connected trusted device and automatically locks your Mac when the signal becomes weak or disappears.

The project currently follows a security-first MVP scope: auto-lock is the primary guarantee, while wake-on-return is best-effort and depends on whether macOS reconnects the device after the screen is locked.

## Features

- Native macOS menu bar app built with SwiftUI and AppKit-bridged system services
- Uses Bluetooth RSSI from an already connected device as the boundary signal
- Smooths noisy signal samples with a sliding window and signal-loss timeout
- Locks the screen automatically when the trusted device moves away or disappears
- Lets you tune lock threshold, wake threshold, timeout, and window size
- Runs entirely on macOS without requiring a phone app

## MVP Scope

- Primary behavior: auto-lock your Mac when the selected device becomes weak or unavailable
- Best-effort behavior: wake the display on return if macOS reconnects the device and exposes a usable RSSI again
- Current platform: macOS only

## Requirements

- macOS 13 or later
- A Bluetooth device that stays connected to your Mac and exposes usable negative RSSI samples
- `xcodegen` installed locally if you want to build from source

## First Run

1. Launch Zone.
2. Allow Bluetooth access when macOS asks.
3. Allow Accessibility access so Zone can trigger the system lock shortcut.
4. Make sure your phone or another trusted Bluetooth device is connected in macOS.
5. In Zone Settings, choose that device as your token.
6. Wait until Zone shows a live negative RSSI value such as `-57 dBm`.
7. Test `Lock Now`, then temporarily turn Bluetooth off on the token device to confirm automatic locking.

For the full walkthrough and troubleshooting tips, see [docs/getting-started.md](/Users/xgm/code/github.com/pengdengke/Zone/docs/getting-started.md).

## Build From Source

Please do not rely on GitHub Actions in the upstream `pengdengke/Zone` repository for your own builds.
If you want GitHub-hosted automation, fork this repository first and run Actions in your own fork.

```bash
xcodegen generate
xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test
./scripts/build_dmg.sh
```

`./scripts/build_dmg.sh` keeps the final unsigned DMG at `build/Zone.dmg`.
Opening that DMG shows a standard drag-to-`Applications` install layout with `Zone.app` and an `Applications` shortcut.

## Continuous Integration

The upstream repository only runs CI for maintainer pushes to `master`.
External users should fork the repository if they want to run GitHub Actions for their own changes.

The CI workflow performs the same checks used locally:

- `swift test`
- `xcodegen generate`
- `xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test`

## Unsigned Builds

Local builds, and any builds you create in your own fork, are intentionally unsigned.
The packaging output is the DMG itself, not a ZIP wrapper.

That means:

- macOS may warn that the app is from an unidentified developer
- users may need to open the app manually through Finder or System Settings
- code signing and notarization are planned for a later release phase

## Known Limitations

- Some phones or Bluetooth profiles stay connected but never expose usable RSSI to macOS. In that case, Zone cannot build a reliable signal boundary from that device.
- Auto wake is best-effort only. If macOS does not reconnect the trusted device after the screen locks, Zone cannot detect your return.
- Zone currently depends on connected-device RSSI, not BLE beacon broadcasting.

## Open Source

Zone is released under the MIT License. See [LICENSE](/Users/xgm/code/github.com/pengdengke/Zone/LICENSE).
