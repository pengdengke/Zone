# Project Learnings

## [LRN-20260402-001] correction

**Logged**: 2026-04-02T14:46:00+08:00
**Priority**: high
**Status**: pending
**Area**: config

### Summary
Development must happen on `develop` or a branch created from `develop`, never directly on `master`.

### Details
The user clarified the repository workflow rule: `master` is the release branch and must not be used for direct development work. Future changes must start on `develop` or a feature branch created from `develop`, then merge back through the normal branch flow before promotion to `master`.

### Suggested Action
Use `develop` as the integration branch for all future work, and only move tested changes into `master` for release preparation and tagging.

### Metadata
- Source: user_feedback
- Related Files: .github/workflows/ci.yml
- Tags: git, branching, release-flow

---
