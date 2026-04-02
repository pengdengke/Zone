# Release-Aware Updates Design

**Goal:** Add version visibility and GitHub Release-based update detection to the app, while making packaged builds depend on an existing formal GitHub Release for the current tag.

## Product Behavior

- `Settings` shows the app's current version.
- The app checks GitHub for the latest formal release once at startup.
- `Settings` shows the latest release version, published date, and a status message.
- `Settings` provides a manual "Check for Updates" action and an "Open Latest Release" action.
- Pre-releases are ignored.
- Packaging fails unless `HEAD` is exactly tagged and GitHub already has a matching non-draft, non-prerelease Release.

## App Architecture

- Add a focused update support module that owns:
  - Current app version loading from the bundle.
  - GitHub Release API fetching.
  - Tag/version parsing and comparison.
  - Release page opening.
- `AppModel` owns update-check state and triggers one background check during startup.
- `SettingsView` renders the version/update section from `AppModel` state without making network requests directly.

## Packaging Architecture

- `build_dmg.sh` resolves the exact tag on `HEAD`.
- The script fetches the matching GitHub Release by tag and verifies:
  - Release exists.
  - `draft == false`
  - `prerelease == false`
- The resolved version is injected into the archive build through `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- The final DMG filename includes the tag, for example `Zone-v1.2.3.dmg`.

## Error Handling

- If the latest release cannot be fetched, the app keeps showing the current version and reports update check failure in `Settings`.
- If the release tag cannot be parsed as a comparable semantic version, the app shows the latest release metadata but avoids claiming whether an update exists.
- Packaging exits with a clear error when the current commit is untagged, the tag is malformed, or GitHub lacks a matching formal Release.

## Testing

- Unit tests cover version parsing/comparison and `AppModel` update state transitions.
- String tests cover the new version/update labels.
- Shell tests cover release-aware packaging behavior, including failure without a Release and version injection into `xcodebuild`.
