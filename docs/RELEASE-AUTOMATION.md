# Release Automation System

This document describes the comprehensive release automation system implemented for the Card Almanac project, following industry standards and best practices.

## Overview

The Card Almanac release automation system provides:

-   **Semantic Versioning**: Automatic version calculation based on git branches and tags
-   **Automated Changelog**: Keep a Changelog format with intelligent commit categorization
-   **Conflict-Free Changelogs**: Per-PR `changelog.d/` fragments collated once at release
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
./build/update-changelog.sh add-unreleased "New feature" "Added"   # legacy manual path
./build/update-changelog.sh finalize           # Move unreleased to version
```

**Features:**

-   Automatic commit categorization (Added/Changed/Fixed/Security/etc.)
-   GitHub compare URL generation
-   Conventional commit detection
-   Unreleased section management

> **Note:** `add-unreleased` (and `make changelog-add`) is the **legacy manual
> path**, kept for entries that are not tied to a pull request. Routine per-PR
> entries go to a `changelog.d/` fragment instead — see
> [Changelog fragments](#changelog-fragments) below.

### 3. Changelog Fragments (`build/collate-changelog.sh`)

Per-PR changelog entries are **not** appended to the shared `## [Unreleased]`
section of `CHANGELOG.md`. Every concurrent PR editing that one block re-conflicts
every other open PR's changelog, so each PR instead writes its own fragment file:

```text
changelog.d/<issue>-<type>.md
```

where `<type>` is one of `added`, `changed`, `deprecated`, `removed`, `fixed`,
`security`. The body is the single Keep a Changelog list line that would have gone
under the matching `### <Type>` heading (plus at most one indented caveat
sub-bullet). Unique path per PR, so this is genuinely zero-conflict. The full
convention lives in [`changelog.d/README.md`](../changelog.d/README.md).

A CI gate (`.github/workflows/changelog-fragment.yaml`) fails any PR that adds no
fragment. Add the `skip-changelog` label to opt a trivial PR (or a Dependabot PR)
out of the gate.

**Usage:**

```bash
./build/collate-changelog.sh                   # Fold fragments into [Unreleased], then delete them
./build/collate-changelog.sh --preview         # Non-destructive: show the assembled [Unreleased]
./build/collate-changelog.sh --changelog FILE --fragments-dir DIR
```

Collation runs **once, at release**: `make changelog-update` and `make
release-prepare` invoke the collator ahead of `build/update-changelog.sh` so the
fragments land in `## [Unreleased]` before the version cut. It is a clean no-op
when no fragments are pending.

### 4. Release Notes Generation (`build/generate-release-notes.sh`)

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
make changelog-preview    # Collate fragments in preview mode, then preview changelog update
make changelog-update     # Collate fragments, then update changelog with current version
make changelog-add        # Legacy: add entry to unreleased section (interactive)
make changelog-finalize   # Move unreleased to version section
```

`changelog-preview` and `changelog-update` run `build/collate-changelog.sh` first
so pending `changelog.d/` fragments are folded into `## [Unreleased]`.
`changelog-add` is the legacy manual path for entries not tied to a PR.

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
| `build/collate-changelog.sh`      | Changelog fragment collation       |
| `build/generate-release-notes.sh` | Release notes generation           |
| `CHANGELOG.md`                    | Project changelog                  |
| `changelog.d/`                    | Per-PR changelog fragments         |
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
# release-prepare collates changelog.d/ fragments into CHANGELOG.md and stages
# their deletion, so `git add -A changelog.d` picks up the consumed fragments.
git add CHANGELOG.md RELEASE_NOTES.md
git add -A changelog.d
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
