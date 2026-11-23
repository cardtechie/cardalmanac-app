#!/bin/bash
#
# Tests for build/recover-untagged-release.sh (issue #577). Each case drives the
# real scripts inside a throwaway git repo, so nothing here touches this
# checkout.
#
# Usage: bash tests/build/recover-untagged-release.test.sh
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="build/recover-untagged-release.sh"

# Isolate git from the caller's global/system config and hooks.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

BOT_NAME="cardtechie-ops-bot[bot]"
BOT_EMAIL="bot@example.com"
SUBJECT_PREFIX="chore(release): collate CHANGELOG for "

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/recover-untagged-release-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASSED=0
FAILED=0
CASE=""

fail() {
    echo "  ✗ ${CASE}: $1" >&2
    FAILED=$((FAILED + 1))
}

pass() {
    echo "  ✓ ${CASE}"
    PASSED=$((PASSED + 1))
}

# A fresh repo at $WORK on main holding the scripts under test and a CHANGELOG
# with an empty [Unreleased] above one released section, tagged 0.0.0.
new_repo() {
    WORK="$(mktemp -d "${TMP_ROOT}/case.XXXXXX")"
    git init -q "$WORK"
    cd "$WORK"
    git symbolic-ref HEAD refs/heads/main
    git config user.name "Test Author"
    git config user.email "test@example.com"
    mkdir -p build changelog.d
    cp "${REPO_ROOT}/build/recover-untagged-release.sh" "${REPO_ROOT}/build/version.sh" build/
    cat > CHANGELOG.md <<'CHANGELOG'
# Changelog

## [Unreleased]

## [0.0.0] - 2025-01-01

### Added

- Initial release.
CHANGELOG
    git add -A
    git commit -q -m "initial"
    git tag 0.0.0
}

# Add a commit-back for $1 (version) authored by $2 with subject prefix $3. The
# commit promotes [Unreleased] to the version and touches only CHANGELOG.md,
# plus the extra path $4 when given.
commit_back() {
    local version="$1" author="$2" prefix="$3" extra="${4:-}"
    sed -i.tmp "s/^## \[Unreleased\]/## [Unreleased]\\
\\
## [${version}] - 2025-02-01\\
\\
### Fixed\\
\\
- A fix./" CHANGELOG.md
    rm -f CHANGELOG.md.tmp
    git add CHANGELOG.md
    if [[ -n "$extra" ]]; then
        mkdir -p "$(dirname "$extra")"
        echo "x" > "$extra"
        git add "$extra"
    fi
    git -c user.name="$author" -c user.email="$BOT_EMAIL" \
        commit -q -m "${prefix}${version}"
}

later_commit() {
    echo "$1" > "$1.txt"
    git add "$1.txt"
    git commit -q -m "later $1"
}

# Run the script, capturing exit status, combined output, and the outputs file.
run_script() {
    OUT_FILE="$(mktemp "${TMP_ROOT}/out.XXXXXX")"
    set +e
    LOG="$(bash "$SCRIPT" --output "$OUT_FILE" 2>&1)"
    RC=$?
    set -e
}

out() { sed -n "s/^$1=//p" "$OUT_FILE" | tail -n 1; }

echo "recover-untagged-release.sh"

# ---------------------------------------------------------------------------
CASE="newest section already tagged: recover=false"
new_repo
run_script
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$(out recover)" != "false" ]]; then fail "recover=$(out recover)"
else pass; fi

# ---------------------------------------------------------------------------
CASE="no versioned section: recover=false"
new_repo
printf '# Changelog\n\n## [Unreleased]\n' > CHANGELOG.md
git commit -q -am "empty changelog"
run_script
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$(out recover)" != "false" ]]; then fail "recover=$(out recover)"
else pass; fi

# ---------------------------------------------------------------------------
CASE="untagged, verified commit-back behind HEAD: recover=true with its sha"
new_repo
commit_back 0.0.1 "$BOT_NAME" "$SUBJECT_PREFIX"
expected="$(git rev-parse HEAD)"
later_commit one
later_commit two
run_script
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$(out recover)" != "true" ]]; then fail "recover=$(out recover)"
elif [[ "$(out version)" != "0.0.1" ]]; then fail "version=$(out version)"
elif [[ "$(out sha)" != "$expected" ]]; then fail "sha=$(out sha), expected $expected"
else pass; fi

# ---------------------------------------------------------------------------
CASE="untagged commit-back that is HEAD itself: recover=true"
new_repo
commit_back 0.0.1 "$BOT_NAME" "$SUBJECT_PREFIX"
expected="$(git rev-parse HEAD)"
run_script
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$(out recover)" != "true" || "$(out sha)" != "$expected" ]]; then fail "recover=$(out recover) sha=$(out sha)"
else pass; fi

# ---------------------------------------------------------------------------
CASE="after tagging the recovered sha, version.sh next yields the following patch"
new_repo
commit_back 0.0.1 "$BOT_NAME" "$SUBJECT_PREFIX"
later_commit one
run_script
git tag "$(out version)" "$(out sha)"
run_script
next="$(bash build/version.sh --branch main next 2>/dev/null | tail -n 1)"
if [[ "$(out recover)" != "false" ]]; then fail "still recovering after tagging: recover=$(out recover)"
elif [[ "$next" != "0.0.2" ]]; then fail "next version was '$next'"
else pass; fi

# ---------------------------------------------------------------------------
CASE="forged author: exit 1 naming the version"
new_repo
commit_back 0.0.1 "Someone Else" "$SUBJECT_PREFIX"
run_script
if [[ $RC -ne 1 ]]; then fail "exit $RC: $LOG"
elif ! grep -q "0\.0\.1" <<< "$LOG" || ! grep -q "gh release create 0\.0\.1" <<< "$LOG"; then fail "message lacks version or command: $LOG"
elif [[ -n "$(out recover)" ]]; then fail "wrote recover=$(out recover)"
else pass; fi

# ---------------------------------------------------------------------------
CASE="subject that only mentions the phrase: exit 1"
new_repo
commit_back 0.0.1 "$BOT_NAME" "fix: mention ${SUBJECT_PREFIX}"
run_script
if [[ $RC -ne 1 ]]; then fail "exit $RC: $LOG"; else pass; fi

# ---------------------------------------------------------------------------
CASE="commit-back that also touches code: exit 1"
new_repo
commit_back 0.0.1 "$BOT_NAME" "$SUBJECT_PREFIX" app/Evil.php
run_script
if [[ $RC -ne 1 ]]; then fail "exit $RC: $LOG"
elif ! grep -q "0\.0\.1" <<< "$LOG"; then fail "message lacks version: $LOG"
else pass; fi

# ---------------------------------------------------------------------------
CASE="commit-back that also drains changelog.d/: recover=true"
new_repo
echo "- frag" > changelog.d/1-fixed.md
git add changelog.d/1-fixed.md
git commit -q -m "add fragment"
git rm -q changelog.d/1-fixed.md
commit_back 0.0.1 "$BOT_NAME" "$SUBJECT_PREFIX"
run_script
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$(out recover)" != "true" ]]; then fail "recover=$(out recover)"
else pass; fi

# ---------------------------------------------------------------------------
CASE="bot commit with the right subject that introduces no section: exit 1"
new_repo
commit_back 0.0.1 "Someone Else" "fix: add "
later_commit one
# A bot-authored commit with the right subject that does not touch the changelog.
echo "y" > y.txt
git add y.txt
git -c user.name="$BOT_NAME" -c user.email="$BOT_EMAIL" commit -q -m "${SUBJECT_PREFIX}0.0.1"
run_script
if [[ $RC -ne 1 ]]; then fail "exit $RC: $LOG"; else pass; fi

echo ""
echo "${PASSED} passed, ${FAILED} failed"
[[ $FAILED -eq 0 ]]
