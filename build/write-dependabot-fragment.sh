#!/bin/bash
#
# Write a changelog.d fragment for a Dependabot PR (issue #543).
#
# Dependabot PRs have no issue, so the fragment is keyed on the PR number:
#   changelog.d/<pr>-security.md  when a GitHub advisory is attached (GHSA_ID)
#   changelog.d/<pr>-changed.md   otherwise (a version update)
#
# Every input arrives through the environment, never through argv or an
# interpolated workflow expression, because package names and versions are
# attacker-influenced text:
#   PR_NUMBER    pull request number (digits only)
#   DEP_NAMES    comma-separated dependency names (Dependabot's own format)
#   NEW_VERSION  new version, used only for a single-dependency PR
#   GHSA_ID      advisory id; non-empty means a security update
#   OUTPUT_FILE  optional; receives `created=true|false` for the workflow
#
# Idempotent: when any changelog.d/<pr>-*.md exists, nothing is written.
#
# Usage: PR_NUMBER=12 DEP_NAMES=foo NEW_VERSION=1.2.3 bash build/write-dependabot-fragment.sh
#

set -euo pipefail

PR_NUMBER="${PR_NUMBER:-}"
DEP_NAMES="${DEP_NAMES:-}"
NEW_VERSION="${NEW_VERSION:-}"
GHSA_ID="${GHSA_ID:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

report() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "created=$1" >> "$OUTPUT_FILE"
    fi
}

if ! [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "❌ Error: PR_NUMBER must be a positive integer, got '${PR_NUMBER}'." >&2
    exit 1
fi

# Allowlist, not a denylist: anything outside it never reaches the file.
if [ -z "$DEP_NAMES" ] || ! [[ "$DEP_NAMES" =~ ^[A-Za-z0-9@/._,\ -]+$ ]]; then
    echo "❌ Error: DEP_NAMES is empty or contains characters outside [A-Za-z0-9@/._, -]." >&2
    exit 1
fi

if [ -n "$NEW_VERSION" ] && ! [[ "$NEW_VERSION" =~ ^[A-Za-z0-9._+-]+$ ]]; then
    echo "❌ Error: NEW_VERSION contains characters outside [A-Za-z0-9._+-]." >&2
    exit 1
fi

if [ -n "$GHSA_ID" ] && ! [[ "$GHSA_ID" =~ ^GHSA(-[a-z0-9]{4}){3}$ ]]; then
    echo "❌ Error: GHSA_ID is not a GHSA identifier." >&2
    exit 1
fi

mkdir -p changelog.d

existing=$(find changelog.d -maxdepth 1 -type f -name "${PR_NUMBER}-*.md" | head -n 1)
if [ -n "$existing" ]; then
    echo "Fragment ${existing} already exists; nothing to do."
    report false
    exit 0
fi

type="changed"
if [ -n "$GHSA_ID" ]; then
    type="security"
fi

# Normalize "a, b,c" to one name per line, dropping empties.
names=$(printf '%s' "$DEP_NAMES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d')
count=$(printf '%s\n' "$names" | wc -l | tr -d ' ')

if [ "$count" -eq 1 ] && [ -n "$NEW_VERSION" ]; then
    body="- **[PR #${PR_NUMBER}]** Bump ${names} to ${NEW_VERSION}."
elif [ "$count" -eq 1 ]; then
    body="- **[PR #${PR_NUMBER}]** Bump ${names}."
else
    joined=$(printf '%s\n' "$names" | paste -sd, - | sed 's/,/, /g')
    body="- **[PR #${PR_NUMBER}]** Bump ${count} dependencies: ${joined}."
fi

fragment="changelog.d/${PR_NUMBER}-${type}.md"
printf '%s\n' "$body" > "$fragment"
echo "Wrote ${fragment}"
report true
