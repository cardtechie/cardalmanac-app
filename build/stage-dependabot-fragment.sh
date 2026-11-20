#!/bin/bash
#
# Stage exactly one changelog.d fragment in a Dependabot PR checkout (issue #561).
#
# Runs in the untrusted PR head checkout, after build/write-dependabot-fragment.sh
# created changelog.d/<pr>-security.md or <pr>-changed.md. A blanket
# `git add changelog.d` would also stage any other edit or deletion a modified
# Dependabot branch carries there, and the next step pushes with the App's
# contents: write token. So this script re-verifies the working tree and stages
# only the single new fragment, failing closed on any deviation:
#   - the index is clean and `git status` shows exactly one entry,
#     `?? changelog.d/<PR_NUMBER>-(security|changed).md`
#   - that entry is a regular file, and changelog.d is not a symlink
#   - after `git add`, the index holds exactly `A <fragment>`
#
# Input arrives through the environment only:
#   PR_NUMBER  pull request number (digits only)
#
# Usage: PR_NUMBER=12 bash build/stage-dependabot-fragment.sh
#

set -euo pipefail

PR_NUMBER="${PR_NUMBER:-}"

if ! [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "❌ Error: PR_NUMBER must be a positive integer, got '${PR_NUMBER}'." >&2
    exit 1
fi

if [ -L changelog.d ]; then
    echo "❌ Error: changelog.d is a symlink; refusing to stage through it." >&2
    exit 1
fi

# Anything already staged would ride along in the commit.
if ! git diff --cached --quiet; then
    echo "❌ Error: the index already holds staged changes; refusing to continue." >&2
    git diff --cached --name-status >&2
    exit 1
fi

status=$(git status --porcelain --untracked-files=all)
if [ -z "$status" ] || [ "$(printf '%s\n' "$status" | wc -l | tr -d ' ')" != "1" ]; then
    echo "❌ Error: expected exactly one new file in the working tree, found:" >&2
    printf '%s\n' "${status:-<nothing>}" >&2
    exit 1
fi

if ! [[ "$status" =~ ^\?\?\ changelog\.d/${PR_NUMBER}-(security|changed)\.md$ ]]; then
    echo "❌ Error: the only change is not changelog.d/${PR_NUMBER}-(security|changed).md:" >&2
    printf '%s\n' "$status" >&2
    exit 1
fi

fragment="${status#\?\? }"

if [ -L "$fragment" ] || ! [ -f "$fragment" ]; then
    echo "❌ Error: ${fragment} is not a regular file; refusing to stage it." >&2
    exit 1
fi

git add -- "$fragment"

expected=$(printf 'A\t%s' "$fragment")
staged=$(git diff --cached --name-status)
if [ "$staged" != "$expected" ]; then
    echo "❌ Error: the index does not hold exactly the new fragment:" >&2
    printf '%s\n' "$staged" >&2
    exit 1
fi

echo "Staged ${fragment}"
