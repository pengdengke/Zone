# Getting Started With Zone

Zone is a macOS menu bar app that turns a connected Bluetooth device into a signal boundary for your Mac.

When the trusted device moves far enough away, or when macOS can no longer read its signal, Zone locks the screen. Returning is currently best-effort and depends on whether macOS reconnects the same device after the screen is locked.

## Before You Start

- Keep Bluetooth enabled on your Mac.
- Pick a trusted device that already connects to macOS over Bluetooth.
- Expect the best results from devices that stay connected and expose a negative RSSI value while nearby.

## Install And Launch

1. Open `Zone.dmg`.
2. Drag `Zone.app` onto the `Applications` shortcut inside the DMG window.
3. Launch Zone from `/Applications`.
4. Look for the shield icon in the macOS menu bar.
5. Open `Zone Settings` from the menu bar.

## First-Run Checklist

### 1. Allow Bluetooth access

Zone needs Bluetooth permission to read the connected device list and current RSSI signal strength.

If macOS asks for Bluetooth access, choose `Allow`.

### 2. Allow Accessibility access

Zone uses the standard macOS lock shortcut to lock the screen on your behalf.

To enable that:

1. Open `System Settings`.
2. Go to `Privacy & Security > Accessibility`.
3. Turn on `Zone`.

After granting access, reopen Zone if macOS does not recognize the permission immediately.

### 3. Choose a trusted device

Zone only lists Bluetooth devices that macOS currently sees as connected.

If your phone or token device is missing:

- reconnect it in macOS Bluetooth settings
- return to Zone
- click `Refresh Connected Devices`

Then choose the device from the `Use this token` picker.

### 4. Confirm a live RSSI signal

Zone needs a live negative RSSI sample such as `-57 dBm`.

If the app still shows `--`:

- keep the device nearby
- reconnect it
- refresh the connected list
- or try another connected Bluetooth device

Without a live RSSI sample, Zone cannot form a reliable signal boundary.

## Test The MVP

1. Confirm `Lock Now` works.
2. Keep the trusted device selected in Zone.
3. Turn Bluetooth off on the trusted device.
4. Wait for the configured signal-loss timeout.
5. Confirm macOS locks automatically.

For the current MVP, this is the primary success path.

## Troubleshooting

### Zone keeps showing `--`

macOS is not exposing a usable negative RSSI value for the current connection.

Try:

- reconnecting the device
- refreshing connected devices
- choosing another connected Bluetooth device

### Zone asks for Accessibility repeatedly

This usually means macOS has not fully applied the permission to the current app process yet.

Try:

1. confirm `Zone` is enabled in `Privacy & Security > Accessibility`
2. quit Zone
3. relaunch Zone
4. test `Lock Now` again

### The device is not listed

Zone does not scan for every nearby device. It only shows devices that macOS currently treats as connected.

Make sure the device is already connected through macOS Bluetooth settings first.

### Auto wake does not happen

This is a known limitation of the current MVP. If macOS does not reconnect the trusted device after the screen locks, Zone has no RSSI signal to use for wake-on-return.

## License

Zone is open source under the MIT License. See [LICENSE](/Users/xgm/code/github.com/pengdengke/Zone/LICENSE).
