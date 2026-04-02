# Release-Aware Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Settings version/update UI backed by GitHub Releases and make DMG packaging require a formal Release for the current git tag.

**Architecture:** Keep update behavior in a small app-side support module and let `AppModel` own the UI state. Make the packaging script resolve a release-backed version before archiving so the bundle version and DMG filename stay aligned with GitHub Releases.

**Tech Stack:** SwiftUI, Foundation networking, XCTest, bash, XcodeGen

---

### Task 1: App Update Support

**Files:**
- Create: `App/Sources/AppUpdateSupport.swift`
- Create: `App/Tests/AppUpdateSupportTests.swift`

- [ ] Step 1: Write failing tests for version parsing and release fetch handling.
- [ ] Step 2: Run the focused tests and confirm they fail for missing update support types.
- [ ] Step 3: Implement the minimal version parsing, release decoding, and live checker abstractions.
- [ ] Step 4: Re-run the focused tests and confirm they pass.

### Task 2: AppModel And Settings

**Files:**
- Modify: `App/Sources/AppModel.swift`
- Modify: `App/Sources/SettingsView.swift`
- Modify: `App/Sources/AppStrings.swift`
- Modify: `App/Tests/AppModelTests.swift`
- Modify: `App/Tests/AppStringsTests.swift`

- [ ] Step 1: Write failing tests for startup update checks, manual retries, and new localized labels.
- [ ] Step 2: Run the focused app tests and confirm they fail with missing model/string behavior.
- [ ] Step 3: Implement update state in `AppModel` and render the new `Settings` section.
- [ ] Step 4: Re-run the focused app tests and confirm they pass.

### Task 3: Release-Gated Packaging

**Files:**
- Modify: `App/Info.plist`
- Modify: `project.yml`
- Modify: `scripts/build_dmg.sh`
- Create: `scripts/tests/build_dmg_release_gate_test.sh`

- [ ] Step 1: Write a failing shell test that expects `build_dmg.sh` to reject missing Releases and pass version settings to `xcodebuild` when a formal Release exists.
- [ ] Step 2: Run the shell test and confirm it fails against the current script.
- [ ] Step 3: Implement release validation, version injection, and versioned DMG output.
- [ ] Step 4: Re-run the shell test and confirm it passes.

### Task 4: Full Verification

**Files:**
- Modify: `scripts/tests/build_dmg_from_scripts_dir_test.sh`

- [ ] Step 1: Re-run focused XCTest coverage for update support and `AppModel`.
- [ ] Step 2: Re-run shell tests for packaging.
- [ ] Step 3: Run the full project test suite and one end-to-end `build_dmg.sh` build if the environment allows it.
