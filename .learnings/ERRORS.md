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
