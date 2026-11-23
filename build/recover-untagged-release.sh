#!/bin/bash

#
# Card Almanac - Recover a collated version that was committed but never tagged
# (issue #577)
#
# Build Release collates CHANGELOG.md, pushes the commit-back to main, and only
# then tags and publishes. If a step after the push fails, main carries a
# `## [X.Y.Z]` section with no tag. `build/version.sh next` then computes X.Y.Z
# again, and build/commit-changelog-back.sh refuses to write it twice (its
# resume path only applies while HEAD is that commit-back), so every later push
# to main fails until someone intervenes by hand.
#
# This script runs BEFORE version calculation and decides whether such a stranded
# release exists:
#   - The newest `## [X.Y.Z]` heading in CHANGELOG.md is tagged, or there is no
#     versioned heading: nothing to recover (recover=false, exit 0).
#   - It is untagged and its commit-back is found and verified: recover=true,
#     with the version and the commit-back sha, so the workflow can tag and
#     release exactly that commit (exit 0).
#   - It is untagged and no commit passes verification: exit 1 with a message
#     naming the version and the manual command, instead of the opaque
#     "refusing to write it twice" on every later push.
#
# Verification of the commit-back mirrors head_is_own_collation_commit in
# build/commit-changelog-back.sh, applied to a commit that is no longer HEAD.
# Author and subject are free text, so they only pre-filter. The CONTENT check
# is what makes tagging safe:
#   - exactly one parent, that parent has no `## [X.Y.Z]` section, and the
#     commit itself has it, so the commit is the one that introduced it;
#   - the diff touches only CHANGELOG.md and changelog.d/, so tagging it
#     releases its parent's code plus the notes; and
#   - it is an ancestor of HEAD, so it is on the branch being released.
# The trust boundary is the one documented in commit-changelog-back.sh: a forged
# match needs write access to main, which can already start a release.
#
# `--output FILE` appends `recover=true|false`, and for true also `version=` and
# `sha=`, to FILE (Build Release passes $GITHUB_OUTPUT).
#
# Needs the tags and full history (Build Release checks out with fetch-depth: 0).
#
# Bash 3.2-safe (macOS), matching the sibling scripts.
#
# Usage:
#   build/recover-untagged-release.sh [--output FILE]
#

set -euo pipefail

COMMIT_SUBJECT_PREFIX="chore(release): collate CHANGELOG for "
BOT_NAME="cardtechie-ops-bot[bot]"
CHANGELOG_FILE="CHANGELOG.md"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

show_usage() {
    echo "Usage: $0 [--output FILE]"
    echo ""
    echo "Detect a collated '## [X.Y.Z]' CHANGELOG section whose commit-back reached"
    echo "the branch but was never tagged, and verify that commit-back."
    echo ""
    echo "  --output FILE   Append recover=true|false (plus version= and sha= when"
    echo "                  true) to FILE (e.g. \$GITHUB_OUTPUT)"
}

OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "❌ Error: --output requires a value" >&2
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown argument '$1'" >&2
            show_usage >&2
            exit 1
            ;;
    esac
done

# Resolve a relative --output against the caller's directory before the cd.
if [[ -n "$OUTPUT_FILE" && "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="${PWD}/${OUTPUT_FILE}"
fi

write_output() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$1" >> "$OUTPUT_FILE"
    fi
}

cd "$PROJECT_ROOT"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository" >&2
    exit 1
fi

if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo "❌ Error: ${CHANGELOG_FILE} not found" >&2
    exit 1
fi

# Newest versioned heading: the first `## [X.Y.Z...]` line, which is how
# build/commit-changelog-back.sh orders sections (newest first, below [Unreleased]).
HEADING=$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9-]+(\.[0-9]+)?)?\]' "$CHANGELOG_FILE" || true)
if [[ -z "$HEADING" ]]; then
    echo "ℹ️  No versioned section in ${CHANGELOG_FILE} — nothing to recover."
    write_output "recover=false"
    exit 0
fi
VERSION="${HEADING#\#\# \[}"
VERSION="${VERSION%%\]*}"

# VERSION came from a regex-validated heading, so it is safe to interpolate.
if git rev-parse -q --verify "refs/tags/${VERSION}" > /dev/null; then
    echo "ℹ️  ${VERSION} is already tagged — nothing to recover."
    write_output "recover=false"
    exit 0
fi

echo "🔎 ${CHANGELOG_FILE} has a '## [${VERSION}]' section but no ${VERSION} tag — looking for its commit-back."

VERSION_RE="${VERSION//./\\.}"

# True when $1 is a verified commit-back for VERSION (content checks only; the
# author and subject pre-filter happens in the caller).
verify_commit_back() {
    local sha="$1" parents parent_changelog path
    parents=$(git rev-list --parents -n 1 "$sha" 2>/dev/null | wc -w | tr -d ' ')
    [[ "$parents" == "2" ]] || return 1

    # Variable, not a `git show | grep -q` pipe: under pipefail grep's early
    # exit can SIGPIPE git show and misread "has the section" as "lacks it".
    parent_changelog=$(git show "${sha}^:${CHANGELOG_FILE}" 2>/dev/null) || return 1
    if grep -q "^## \[${VERSION_RE}\]" <<< "$parent_changelog"; then
        return 1
    fi

    # The candidate itself must carry the section. Without this a bot-authored
    # commit with the right subject that only touches CHANGELOG.md or
    # changelog.d/, followed by a later commit that adds the heading, would be
    # selected and tagged BEFORE the section existed, releasing empty notes.
    local own_changelog
    own_changelog=$(git show "${sha}:${CHANGELOG_FILE}" 2>/dev/null) || return 1
    grep -q "^## \[${VERSION_RE}\]" <<< "$own_changelog" || return 1

    local changed=0
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        case "$path" in
            "$CHANGELOG_FILE"|changelog.d/*) changed=1 ;;
            *) return 1 ;;
        esac
    done < <(git diff-tree --no-commit-id --name-only -r "${sha}^" "$sha")
    [[ "$changed" == "1" ]] || return 1

    git merge-base --is-ancestor "$sha" HEAD
}

FOUND_SHA=""
while IFS=$'\t' read -r sha author subject; do
    [[ -z "$sha" ]] && continue
    [[ "$author" == "$BOT_NAME" && "$subject" == "${COMMIT_SUBJECT_PREFIX}${VERSION}" ]] || continue
    if verify_commit_back "$sha"; then
        FOUND_SHA="$sha"
        break
    fi
done < <(git log --format='%H%x09%an%x09%s' HEAD)

if [[ -z "$FOUND_SHA" ]]; then
    echo "❌ Error: ${CHANGELOG_FILE} has a '## [${VERSION}]' section but no ${VERSION} tag, and no" >&2
    echo "   verified commit-back for it is an ancestor of HEAD, so it cannot be recovered" >&2
    echo "   automatically. Find the commit that introduced the section, then tag and" >&2
    echo "   release it by hand:" >&2
    echo "     gh release create ${VERSION} --target <commit-sha> --title \"Release ${VERSION}\" --notes-file <notes>" >&2
    exit 1
fi

echo "♻️  Found the commit-back for ${VERSION}: ${FOUND_SHA}"
write_output "recover=true"
write_output "version=${VERSION}"
write_output "sha=${FOUND_SHA}"
