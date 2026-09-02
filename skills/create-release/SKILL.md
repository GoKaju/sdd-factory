---
name: create-release
description: Create a versioned GitHub release from main that triggers the CD pipeline
---

## When to use

Use this skill when the user asks to:

- Create a new release
- Deploy to production
- Tag a new version
- Release the SDK

## Prerequisites

Before creating a release, verify:

1. You are on the `main` branch and it is up to date with `origin/main`
2. There are no open PRs that should be merged first
3. There are new commits since the last release

### Check commands

```bash
# Ensure on main and up to date
git checkout main && git pull origin main

# List open PRs — warn the user if any exist
gh pr list --state open --json number,title,isDraft

# Show commits since last release
gh release view --json tagName --jq '.tagName' 2>/dev/null && \
  git log "$(gh release view --json tagName --jq '.tagName')"..HEAD --oneline
```

**Ask the user to confirm** before proceeding if there are open PRs or if there are no new commits since the last release.

## Release types

### Application release (CD deploy)

**Tag format**: `v{YYYY.MM.DD}-{short-sha}`

- Date portion: release date (e.g., `2026.04.10`)
- SHA portion: 7-character short hash of the HEAD commit on `main`
- Example: `v2026.04.10-e974370`

```bash
TAG="v$(date +%Y.%m.%d)-$(git rev-parse --short HEAD)"
gh release create "$TAG" --target main --title "$TAG" --generate-notes
```

Triggers: CD workflow (`.github/workflows/cd.yml`) on `release: [published]`

## Post-release

After creating the release:

1. Share the release URL with the user
2. For app releases: remind them that the CD workflow triggers automatically — no manual deploy needed

## Key rules

- **Never** create a release from a branch other than `main`
- **Never** create a release if `main` is behind `origin/main` — always pull first
- **Ask the user** to confirm before creating the release
- App tags must follow `v{YYYY.MM.DD}-{short-sha}` format exactly
