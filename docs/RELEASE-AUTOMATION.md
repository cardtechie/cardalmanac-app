# Release Automation System

This document describes the comprehensive release automation system implemented for the Card Almanac project, following industry standards and best practices.

## Overview

The Card Almanac release automation system provides:

-   **Semantic Versioning**: Automatic version calculation based on git branches and tags
-   **Automated Changelog**: Keep a Changelog format with intelligent commit categorization
-   **AI-Powered Release Notes**: Claude API integration for intelligent release summaries
-   **Branch-Aware Workflows**: Different version strategies for different branch types
-   **GitHub Integration**: Enhanced labels, issue automation, and release workflows

## Quick Start

### Basic Usage

```bash
# Check current version
make version

# Preview next release
make release-preview

# Update changelog for current version
make changelog-update

# Generate release notes
make release-notes
```

### Release Workflow

```bash
# 1. Preview what the release will look like
make release-preview

# 2. Prepare release artifacts
make release-prepare

# 3. Review CHANGELOG.md and RELEASE_NOTES.md

# 4. Commit and tag release
git add CHANGELOG.md RELEASE_NOTES.md
git commit -m "Prepare release $(make version)"
git tag "v$(make version)"
git push origin main --tags
```

## Branching Model

This repository uses two long-lived branches. The split is deliberate and asymmetric; issue #405 records what happens when it is allowed to drift.

| Branch    | Role                                                                                                                    |
| --------- | ----------------------------------------------------------------------------------------------------------------------- |
| `main`    | Default branch. The stable branch — this is what deploys, and every push to it cuts a release via `build-release.yaml`. |
| `develop` | Integration branch. Feature and bugfix work lands here first and is promoted to `main` as a deliberate release step.    |

### Sync direction

-   **`main` → `develop` is automated.** `.github/workflows/back-merge-stable-to-develop.yml` runs on every push to `main`. It pushes `develop` directly when the merge is clean, and opens an `auto/sync-main-to-develop` PR when it conflicts. Resolve that PR promptly — until it merges, `develop` is missing released work.
-   **`develop` → `main` is not automated.** Promotion is a deliberate release step (see [Release Process](#release-process) below). Nothing auto-promotes, because every push to `main` releases.
-   **`.github/workflows/branch-drift-guard.yaml`** is the backstop. It runs weekly and fails when `develop` falls more than five commits behind `main`, which catches the case where the back-merge workflow itself is stuck or stopped firing. It deliberately ignores the other direction: `develop` being ahead of `main` is the normal state of an integration branch.

### Trigger-bound workflows must live on `main`

**Any workflow whose trigger only fires from the default branch must be merged to `main` to take effect.** That includes:

-   `on: schedule`
-   `on: push: branches: [main]`
-   `workflow_dispatch` (only offered on the default branch)

A workflow like this merged to `develop` looks shipped and never runs once. This is not hypothetical — it is how the back-merge workflow, which exists specifically to prevent branch drift, spent weeks stranded on `develop` unable to fire (#393/#395, landed on `main` by #405), and why #402's scheduled certificate-renewal workflow had to be re-landed as #404. When a change adds or edits a workflow with a default-branch-only trigger, target `main` regardless of what the issue's milestone or branch-type convention would otherwise suggest.

## Components

### 1. Version Management (`build/version.sh`)

Provides semantic versioning with branch-aware version calculation:

-   **master/main**: Final releases (1.2.3)
-   **develop**: Beta releases (1.2.3-beta.N)
-   **release/\***: Release candidates (1.2.3-rc.N)
-   **hotfix/\***: Hotfix releases (1.2.4)
-   **feature/\***: Feature versions (1.2.3-feature.branch-name)
-   **other**: Development versions (1.2.3-dev.sha)

**Usage:**

```bash
./build/version.sh current           # Show current version
./build/version.sh next-major        # Calculate next major version
./build/version.sh next-minor        # Calculate next minor version
./build/version.sh next-patch        # Calculate next patch version
./build/version.sh set-env           # Set environment variables for CI
```

**Options:**

-   `--branch BRANCH`: Override branch detection
-   `--format FORMAT`: Output format (version|tag|env)
-   `--verbose`: Enable verbose output

### 2. Changelog Management (`build/update-changelog.sh`)

Automated changelog management following [Keep a Changelog](https://keepachangelog.com) format:

**Usage:**

```bash
./build/update-changelog.sh init               # Initialize CHANGELOG.md
./build/update-changelog.sh preview            # Preview changes
./build/update-changelog.sh update             # Update with current version
./build/update-changelog.sh update 1.2.3       # Update with specific version
./build/update-changelog.sh add-unreleased "New feature" "Added"
./build/update-changelog.sh finalize           # Move unreleased to version
```

**Features:**

-   Automatic commit categorization (Added/Changed/Fixed/Security/etc.)
-   GitHub compare URL generation
-   Conventional commit detection
-   Unreleased section management

### 3. Release Notes Generation (`build/generate-release-notes.sh`)

AI-powered release notes with Claude API integration:

**Usage:**

```bash
./build/generate-release-notes.sh              # Generate markdown release notes
./build/generate-release-notes.sh --format github    # GitHub release format
./build/generate-release-notes.sh --format text      # Plain text format
./build/generate-release-notes.sh --no-ai           # Skip AI, use template only
```

**Features:**

-   Claude API integration for intelligent summaries
-   Multiple output formats (markdown/github/text)
-   Docker image information
-   GitHub integration with compare URLs
-   Fallback mode when AI is unavailable

**Environment Variables:**

-   `CLAUDE_API_KEY`: Claude API key for AI-powered summaries
-   `GITHUB_TOKEN`: GitHub API token for enhanced metadata

## Makefile Commands

### Version Management

```bash
make version              # Show current version
make version-preview      # Show all version options
make version-major        # Show next major version
make version-minor        # Show next minor version
make version-patch        # Show next patch version
```

### Changelog Management

```bash
make changelog-preview    # Preview changelog update
make changelog-update     # Update changelog with current version
make changelog-add        # Add entry to unreleased section (interactive)
make changelog-finalize   # Move unreleased to version section
```

### Release Notes

```bash
make release-notes        # Generate release notes (markdown)
make release-notes-preview # Preview release notes
make release-notes-github # Generate GitHub release format
make release-notes-text   # Generate plain text format
```

### Release Workflow

```bash
make release-preview      # Preview complete release
make release-prepare      # Prepare changelog and release notes
make release-help         # Show all release commands
```

## GitHub Integration

### Enhanced Labels (`/.github/labels.yaml`)

Comprehensive label system with categories:

-   **Priority**: `priority: critical`, `priority: high`, `priority: medium`, `priority: low`
-   **Type**: `type: bug`, `type: feature`, `type: enhancement`, `type: security`
-   **Status**: `status: in-progress`, `status: needs-review`, `status: blocked`
-   **Component**: `component: frontend`, `component: backend`, `component: docker`
-   **Area**: `area: cards`, `area: sets`, `area: search`, `area: authentication`
-   **Scope**: `scope: breaking`, `scope: major`, `scope: minor`, `scope: patch`

### Issue Branch Automation (`/.github/issue-branch.yml`)

Automatic branch creation based on issue labels:

-   `type: bug` → `hotfix/123-issue-title`
-   `type: feature` → `feature/123-issue-title`
-   `type: maintenance` → `chore/123-issue-title`
-   `type: documentation` → `docs/123-issue-title`

## Configuration Files

| File                              | Purpose                            |
| --------------------------------- | ---------------------------------- |
| `build/version.sh`                | Version calculation and management |
| `build/update-changelog.sh`       | Changelog automation               |
| `build/generate-release-notes.sh` | Release notes generation           |
| `CHANGELOG.md`                    | Project changelog                  |
| `.github/labels.yaml`             | GitHub label definitions           |
| `.github/issue-branch.yml`        | Issue branch automation            |

## Environment Variables

### Required

-   `TRADINGCARDAPI_CLIENT_ID`: API client ID
-   `TRADINGCARDAPI_CLIENT_SECRET`: API client secret

### Optional

-   `CLAUDE_API_KEY`: Enable AI-powered release summaries
-   `GITHUB_TOKEN`: Enhanced GitHub integration
-   `DOCKER_TAG_*`: Override Docker image tags

## Branch Strategies

### Version Calculation Examples

| Branch              | Example Version              | Description            |
| ------------------- | ---------------------------- | ---------------------- |
| `main`              | `1.2.3`                      | Final release version  |
| `develop`           | `1.3.0-beta.5`               | Beta with commit count |
| `release/1.2.3`     | `1.2.3-rc.2`                 | Release candidate      |
| `hotfix/urgent-fix` | `1.2.4-hotfix.1`             | Hotfix version         |
| `feature/new-cards` | `1.2.3-feature.new-cards.10` | Feature branch         |
| `other-branch`      | `1.2.3-dev.abc123`           | Development version    |

### Release Process

#### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/new-feature

# Work on feature
# ...

# Check version
make version  # Shows: 1.2.3-feature.new-feature.5
```

#### 2. Prepare Release

```bash
# Switch to develop branch
git checkout develop

# Preview release
make release-preview

# Prepare release artifacts
make release-prepare

# Review and commit
git add CHANGELOG.md RELEASE_NOTES.md
git commit -m "Prepare release 1.3.0-beta.1"
```

#### 3. Final Release

```bash
# Switch to main branch
git checkout main
git merge develop

# Create release
make release-prepare

# Tag and push
git tag "v$(make version)"
git push origin main --tags
```

## Claude API Integration

### Setup

1. Get Claude API key from Anthropic
2. Set environment variable: `export CLAUDE_API_KEY="your-api-key"`
3. Generate release notes: `make release-notes`

### Features

-   Intelligent commit summarization
-   User-focused release descriptions
-   Automatic categorization
-   Professional formatting

### Fallback

If Claude API is unavailable:

-   System falls back to template-based generation
-   All functionality remains available
-   No interruption to release process

## Troubleshooting

### Common Issues

**1. Version script shows unexpected version**

```bash
# Check current branch
git branch --show-current

# Verify tags
git tag -l "v*.*.*" | sort -V | tail -5

# Debug version calculation
./build/version.sh --verbose current
```

**2. Changelog generation fails**

```bash
# Check git repository
git status

# Verify script permissions
ls -la build/update-changelog.sh

# Test with specific version
./build/update-changelog.sh preview 1.2.3
```

**3. Release notes generation hangs**

```bash
# Use no-AI mode
make release-notes-preview

# Check API key
echo $CLAUDE_API_KEY

# Generate without AI
./build/generate-release-notes.sh --no-ai
```

### Debug Commands

```bash
# Version debugging
./build/version.sh --verbose current

# Changelog debugging
./build/update-changelog.sh --verbose preview

# Release notes debugging
./build/generate-release-notes.sh --verbose --no-ai
```

## Best Practices

### 1. Commit Messages

Use conventional commit format for better categorization:

```
feat: add new card search functionality
fix: resolve authentication timeout issue
docs: update API documentation
chore: update dependencies
```

### 2. Branch Management

-   Use descriptive branch names
-   Follow the branch type conventions
-   Keep feature branches focused and small

### 3. Release Preparation

-   Always run `make release-preview` first
-   Review generated changelog and release notes
-   Test the release in staging environment
-   Use semantic version increments appropriately

### 4. Issue Management

-   Apply appropriate labels to issues
-   Use issue templates for consistency
-   Link PRs to issues for automatic tracking

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Set Version
  run: ./build/version.sh set-env

- name: Update Changelog
  run: ./build/update-changelog.sh update

- name: Generate Release Notes
  run: ./build/generate-release-notes.sh > RELEASE_NOTES.md
  env:
      CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
```

### Docker Integration

The system automatically generates Docker image tags and includes them in release notes:

```
picklewagon/cardalmanac-app:1.2.3
picklewagon/cardalmanac-app:latest
```

## Future Enhancements

Planned improvements to the release automation system:

1. **GitHub Releases**: Automatic GitHub release creation
2. **Slack Integration**: Release notifications
3. **Dependency Tracking**: Automated dependency updates
4. **Performance Metrics**: Release performance tracking
5. **Rollback Automation**: Automated rollback procedures

## Support

For issues with the release automation system:

1. Check this documentation
2. Review the troubleshooting section
3. Test individual components (`./build/*.sh --help`)
4. Create an issue with the `type: maintenance` label

---

This release automation system brings the Card Almanac project up to professional standards, providing reliable, consistent, and automated release management that scales with the project's growth.
