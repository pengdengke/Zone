## [ERR-20260331-001] git-commit

**Logged**: 2026-03-31T18:00:00+08:00
**Priority**: high
**Status**: pending
**Area**: infra

### Summary
`git commit` failed because a stale `.git/index.lock` file was present in the repository.

### Error
```text
fatal: Unable to create '/Users/xgm/code/github.com/pengdengke/Zone/.git/index.lock': File exists.

Another git process seems to be running in this repository, e.g.
an editor opened by 'git commit'. Please make sure all processes
are terminated then try again. If it still fails, a git process
may have crashed in this repository earlier:
remove the file manually to continue.
```

### Context
- Command attempted: `git commit -m "docs: add Zone macOS RSSI boundary design"`
- Repository state: first commit on newly created `develop` branch
- The index lock likely remained after an earlier interrupted git operation

### Suggested Fix
Check whether another git process is active. If no git process owns the lock, remove the stale `.git/index.lock` file and retry the commit.

### Metadata
- Reproducible: unknown
- Related Files: .git/index.lock

---

## [ERR-20260331-002] git-status-ignored-flag

**Logged**: 2026-03-31T18:45:00+08:00
**Priority**: medium
**Status**: pending
**Area**: infra

### Summary
Used an invalid `git status --ignored=.traditional` flag form while checking repository hygiene.

### Error
```text
fatal: Invalid ignored mode '.traditional'
```

### Context
- Command attempted: `git -C /Users/xgm/code/github.com/pengdengke/Zone status --short --ignored=.traditional`
- Goal: inspect ignored and untracked entries in the main repository after reviewing worktree hygiene
- Correct syntax is `git status --short --ignored=traditional` or plain `git status --short --ignored`

### Suggested Fix
Use a valid `--ignored` mode value without a leading dot.

### Metadata
- Reproducible: yes
- Related Files: .learnings/ERRORS.md

---

## [ERR-20260401-001] xcodebuild-test-selection

**Logged**: 2026-04-01T02:24:20Z
**Priority**: medium
**Status**: pending
**Area**: tests

### Summary
`xcodebuild test` failed when the command targeted `ZoneCoreTests` because that package test target is not part of the app scheme's test plan.

### Error
```text
xcodebuild: error: Failed to build project Zone with scheme Zone.: Tests in the target “ZoneCoreTests” can’t be run because “ZoneCoreTests” isn’t a member of the specified test plan or scheme.
```

### Context
- Command attempted: `xcodebuild -project Zone.xcodeproj -scheme Zone -destination 'platform=macOS' test -only-testing:ZoneTests/AppModelTests -only-testing:ZoneCoreTests/BoundaryEngineTests`
- Repository layout: `ZoneCoreTests` are exercised through the Swift package, while the Xcode scheme currently only exposes `ZoneTests`
- Follow-up verification succeeded by splitting the commands into `swift test` for package tests and `xcodebuild ... -only-testing:ZoneTests/AppModelTests` for app tests

### Suggested Fix
Keep package verification on `swift test` unless the Xcode scheme is updated to include `ZoneCoreTests` in its test plan.

### Metadata
- Reproducible: yes
- Related Files: Zone.xcodeproj

---
