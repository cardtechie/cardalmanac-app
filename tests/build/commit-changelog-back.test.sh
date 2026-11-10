#!/bin/bash
#
# Tests for build/commit-changelog-back.sh and build/collate-changelog.sh
# (issue #542). Each case drives the real scripts inside a throwaway git repo
# with a bare origin, so nothing here touches this checkout.
#
# Usage: bash tests/build/commit-changelog-back.test.sh
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="build/commit-changelog-back.sh"

# Isolate git from the caller's global/system config and hooks.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

BOT_NAME="cardtechie-ops-bot[bot]"
SUBJECT_PREFIX="chore(release): collate CHANGELOG for "

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/commit-changelog-back-test.XXXXXX")"
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

# Create a fresh repo at $WORK with a bare origin at $ORIGIN, holding the
# scripts under test and a CHANGELOG.md with an empty [Unreleased] above one
# released section. Leaves the shell in $WORK.
new_repo() {
    local dir
    dir="$(mktemp -d "${TMP_ROOT}/case.XXXXXX")"
    ORIGIN="${dir}/origin.git"
    WORK="${dir}/work"
    git init -q --bare "$ORIGIN"
    git -C "$ORIGIN" symbolic-ref HEAD refs/heads/main
    git init -q "$WORK"
    cd "$WORK"
    git symbolic-ref HEAD refs/heads/main
    # Repo-local identity, not GIT_AUTHOR_* env vars: those would override the
    # script's own `-c user.name=` and mask the bot author under test.
    git config user.name "Test Author"
    git config user.email "test@example.com"
    git remote add origin "$ORIGIN"
    mkdir -p build changelog.d
    cp "${REPO_ROOT}/build/commit-changelog-back.sh" "${REPO_ROOT}/build/collate-changelog.sh" build/
    cat > CHANGELOG.md <<'CHANGELOG'
# Changelog

## [Unreleased]

## [0.0.0] - 2025-01-01

### Added

- Initial release.
CHANGELOG
    git add -A
    git commit -q -m "initial"
    git push -q origin HEAD:main
}

add_fragment() {
    mkdir -p changelog.d
    printf '%s\n' "$2" > "changelog.d/$1"
    git add "changelog.d/$1"
    git commit -q -m "add fragment $1"
    git push -q origin HEAD:main
}

# Run the script, capturing exit status, combined output, and release= result.
run_script() {
    OUT_FILE="$(mktemp "${TMP_ROOT}/out.XXXXXX")"
    set +e
    LOG="$(bash "$SCRIPT" "$@" --output "$OUT_FILE" 2>&1)"
    RC=$?
    set -e
    RESULT="$(sed -n 's/^release=//p' "$OUT_FILE" | tail -n 1)"
}

head_sha() { git rev-parse HEAD; }

echo "commit-changelog-back.sh"

# ---------------------------------------------------------------------------
CASE="no fragments: release=false, exit 0, no commit"
new_repo
before="$(head_sha)"
run_script 0.0.1 --branch main
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$RESULT" != "false" ]]; then fail "release=$RESULT"
elif [[ "$(head_sha)" != "$before" ]]; then fail "a commit was created"
else pass; fi

# ---------------------------------------------------------------------------
CASE="fragments collate under [0.0.1], drain changelog.d/, commit as the bot"
new_repo
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
add_fragment 2-fixed.md "- **[Issue #2]** Fix a thing."
before="$(head_sha)"
run_script 0.0.1 --branch main
today="$(date -u +%Y-%m-%d)"
unreleased_body="$(sed -n '/^## \[Unreleased\]/,/^## \[/p' CHANGELOG.md | sed '1d;$d' | tr -d '[:space:]')"
section="$(sed -n '/^## \[0\.0\.1\]/,/^## \[0\.0\.0\]/p' CHANGELOG.md)"
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$RESULT" != "true" ]]; then fail "release=$RESULT"
elif ! grep -q "^## \[0\.0\.1\] - ${today}$" CHANGELOG.md; then fail "no [0.0.1] heading"
elif [[ -n "$unreleased_body" ]]; then fail "[Unreleased] is not empty"
elif ! grep -q '^### Added$' <<< "$section" || ! grep -q 'Issue #1' <<< "$section"; then fail "added entry missing"
elif ! grep -q '^### Fixed$' <<< "$section" || ! grep -q 'Issue #2' <<< "$section"; then fail "fixed entry missing"
elif [[ -n "$(ls changelog.d 2>/dev/null)" ]]; then fail "changelog.d/ not drained"
elif [[ "$(git rev-parse HEAD^)" != "$before" ]]; then fail "expected exactly one new commit"
elif [[ "$(git log -1 --format=%s)" != "${SUBJECT_PREFIX}0.0.1" ]]; then fail "wrong subject"
elif [[ "$(git log -1 --format=%an)" != "$BOT_NAME" ]]; then fail "wrong author"
elif [[ "$(git -C "$ORIGIN" rev-parse main)" != "$(head_sha)" ]]; then fail "commit-back not pushed"
else pass; fi

# ---------------------------------------------------------------------------
# The state just after a commit-back push: the bot's own push to main must not
# cut a second release, even with a new VERSION.
CASE="re-run after commit-back with a new version: release=false, no commit"
before="$(head_sha)"
run_script 0.0.2 --branch main
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$RESULT" != "false" ]]; then fail "release=$RESULT"
elif [[ "$(head_sha)" != "$before" ]]; then fail "a commit was created"
elif grep -q '^## \[0\.0\.2\]' CHANGELOG.md; then fail "wrote a [0.0.2] section"
else pass; fi

# ---------------------------------------------------------------------------
CASE="resume at our own commit-back: release=true, no new commit"
before="$(head_sha)"
run_script 0.0.1 --branch main
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$RESULT" != "true" ]]; then fail "release=$RESULT"
elif [[ "$(head_sha)" != "$before" ]]; then fail "a commit was created"
else pass; fi

# ---------------------------------------------------------------------------
CASE="resume refused once main moved past the commit-back"
add_fragment 3-changed.md "- **[Issue #3]** Change a thing."
before="$(head_sha)"
run_script 0.0.1 --branch main
if [[ $RC -eq 0 ]]; then fail "expected a non-zero exit"
elif [[ "$(head_sha)" != "$before" ]]; then fail "a commit was created"
else pass; fi

# ---------------------------------------------------------------------------
CASE="duplicate version written by hand is refused"
new_repo
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
sed -i.tmp 's/^## \[0\.0\.0\] - 2025-01-01$/## [0.0.1] - 2025-01-01/' CHANGELOG.md && rm -f CHANGELOG.md.tmp
git commit -q -am "hand-written version section"
before="$(head_sha)"
run_script 0.0.1 --branch main
if [[ $RC -eq 0 ]]; then fail "expected a non-zero exit"
elif ! grep -q 'refusing to write it twice' <<< "$LOG"; then fail "unexpected message: $LOG"
elif [[ "$(head_sha)" != "$before" ]]; then fail "a commit was created"
elif [[ ! -f changelog.d/1-added.md ]]; then fail "fragment was consumed"
else pass; fi

# ---------------------------------------------------------------------------
# Each bad fragment must be refused before CHANGELOG.md or changelog.d/ change.
refuse_case() {
    local name="$1" expect="$2"
    CASE="$name fragment is refused before anything changes"
    before="$(head_sha)"
    changelog_before="$(cat CHANGELOG.md)"
    run_script 0.0.1 --branch main
    if [[ $RC -eq 0 ]]; then fail "expected a non-zero exit"
    elif ! grep -q "$expect" <<< "$LOG"; then fail "unexpected message: $LOG"
    elif [[ "$(head_sha)" != "$before" ]]; then fail "a commit was created"
    elif [[ "$(cat CHANGELOG.md)" != "$changelog_before" ]]; then fail "CHANGELOG.md changed"
    elif [[ ! -e changelog.d/1-added.md && ! -L changelog.d/1-added.md ]]; then fail "a fragment was consumed"
    else pass; fi
}

new_repo
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
: > changelog.d/2-fixed.md
refuse_case "empty" "no release-note line"

new_repo
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
printf '### Fixed\n\n' > changelog.d/2-fixed.md
refuse_case "heading-only" "no release-note line"

new_repo
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
printf 'secret\n' > "${TMP_ROOT}/outside.txt"
ln -s "${TMP_ROOT}/outside.txt" changelog.d/2-fixed.md
refuse_case "symlinked" "not regular files"

# The collator carries the same guard for direct callers.
CASE="collate-changelog.sh refuses a symlinked fragment"
set +e
LOG="$(bash build/collate-changelog.sh 2>&1)"
RC=$?
set -e
if [[ $RC -eq 0 ]]; then fail "expected a non-zero exit"
elif ! grep -q 'not a regular file' <<< "$LOG"; then fail "unexpected message: $LOG"
elif [[ ! -f changelog.d/1-added.md ]]; then fail "a fragment was consumed"
else pass; fi

# ---------------------------------------------------------------------------
CASE="rejected push exits non-zero with the bypass message"
new_repo
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
cat > "${ORIGIN}/hooks/pre-receive" <<'HOOK'
#!/bin/sh
echo "rejected by test hook" >&2
exit 1
HOOK
chmod +x "${ORIGIN}/hooks/pre-receive"
run_script 0.0.1 --branch main
if [[ $RC -eq 0 ]]; then fail "expected a non-zero exit"
elif ! grep -q 'NOT tagged or published' <<< "$LOG"; then fail "missing not-published message: $LOG"
elif ! grep -q 'bypass actor' <<< "$LOG"; then fail "missing bypass message: $LOG"
elif [[ "$RESULT" == "true" ]]; then fail "reported release=true"
else pass; fi

# ---------------------------------------------------------------------------
CASE="promotion updates the Keep-a-Changelog link references"
new_repo
cat >> CHANGELOG.md <<'LINKS'

[Unreleased]: https://github.com/example/repo/compare/0.0.0...HEAD
[0.0.0]: https://github.com/example/repo/releases/tag/0.0.0
LINKS
git commit -q -am "add link references"
git push -q origin HEAD:main
add_fragment 1-added.md "- **[Issue #1]** Add a thing."
run_script 0.0.1 --branch main
links="$(grep '^\[' CHANGELOG.md)"
expected="[Unreleased]: https://github.com/example/repo/compare/0.0.1...HEAD
[0.0.1]: https://github.com/example/repo/compare/0.0.0...0.0.1
[0.0.0]: https://github.com/example/repo/releases/tag/0.0.0"
if [[ $RC -ne 0 ]]; then fail "exit $RC: $LOG"
elif [[ "$RESULT" != "true" ]]; then fail "release=$RESULT"
elif [[ "$links" != "$expected" ]]; then fail "unexpected link references: $links"
elif [[ -n "$(git status --porcelain)" ]]; then fail "working tree not clean after commit-back"
else pass; fi

# ---------------------------------------------------------------------------
CASE="--is-collation-commit matches only prefix plus bot"
ok=true
bash "$SCRIPT" --is-collation-commit "${SUBJECT_PREFIX}1.2.3" "$BOT_NAME" || ok=false
if bash "$SCRIPT" --is-collation-commit "${SUBJECT_PREFIX}1.2.3" "Someone Else"; then ok=false; fi
if bash "$SCRIPT" --is-collation-commit "fix: mention ${SUBJECT_PREFIX}1.2.3" "$BOT_NAME"; then ok=false; fi
if [[ "$ok" == "true" ]]; then pass; else fail "matched the wrong pair"; fi

echo ""
echo "${PASSED} passed, ${FAILED} failed"
[[ $FAILED -eq 0 ]]
