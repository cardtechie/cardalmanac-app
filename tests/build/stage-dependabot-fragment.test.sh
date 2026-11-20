#!/bin/bash
#
# Tests for build/stage-dependabot-fragment.sh (issue #561). Each case builds a
# throwaway git repository and runs the real script inside it, so nothing
# touches this checkout.
#
# Usage: bash tests/build/stage-dependabot-fragment.test.sh
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/build/stage-dependabot-fragment.sh"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stage-dependabot-fragment-test.XXXXXX")"
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

# A repo with one committed fragment (changelog.d/1-added.md). Sets $WORK.
new_repo() {
    WORK="$(mktemp -d "${TMP_ROOT}/case.XXXXXX")"
    (
        cd "$WORK"
        git init -q
        git config user.name test
        git config user.email test@example.com
        mkdir changelog.d
        echo "- existing" > changelog.d/1-added.md
        git add changelog.d
        git commit -q -m init
    )
}

# Run the script in $WORK with the given env assignments. Sets $RC.
run_stage() {
    RC=0
    (cd "$WORK" && env -i PATH="$PATH" HOME="$TMP_ROOT" "$@" bash "$SCRIPT") > "${TMP_ROOT}/out.log" 2>&1 || RC=$?
}

staged() {
    git -C "$WORK" diff --cached --name-status
}

CASE="stages only the new <pr>-changed.md"
new_repo
echo "- **[PR #12]** Bump foo." > "${WORK}/changelog.d/12-changed.md"
run_stage PR_NUMBER=12
if [ "$RC" -eq 0 ] && [ "$(staged)" = "$(printf 'A\tchangelog.d/12-changed.md')" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="stages only the new <pr>-security.md"
new_repo
echo "- **[PR #13]** Bump foo." > "${WORK}/changelog.d/13-security.md"
run_stage PR_NUMBER=13
if [ "$RC" -eq 0 ] && [ "$(staged)" = "$(printf 'A\tchangelog.d/13-security.md')" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="extra untracked file in changelog.d is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/14-changed.md"
echo "- extra" > "${WORK}/changelog.d/99-added.md"
run_stage PR_NUMBER=14
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="extra untracked file outside changelog.d is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/15-changed.md"
echo "stray" > "${WORK}/stray.txt"
run_stage PR_NUMBER=15
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="modified tracked fragment is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/16-changed.md"
echo "- tampered" > "${WORK}/changelog.d/1-added.md"
run_stage PR_NUMBER=16
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="deleted tracked fragment is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/17-changed.md"
rm "${WORK}/changelog.d/1-added.md"
run_stage PR_NUMBER=17
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="fragment with the wrong PR number is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/18-changed.md"
run_stage PR_NUMBER=19
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="fragment with the wrong type is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/20-added.md"
run_stage PR_NUMBER=20
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="symlinked fragment is rejected"
new_repo
echo "target" > "${WORK}/target.txt"
git -C "$WORK" add target.txt && git -C "$WORK" commit -q -m target
ln -s ../target.txt "${WORK}/changelog.d/21-changed.md"
run_stage PR_NUMBER=21
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="symlinked changelog.d is rejected"
WORK="$(mktemp -d "${TMP_ROOT}/case.XXXXXX")"
(
    cd "$WORK"
    git init -q
    git config user.name test
    git config user.email test@example.com
    mkdir outside
    echo "- x" > outside/22-changed.md
    ln -s outside changelog.d
    git add outside
    git commit -q -m init
)
run_stage PR_NUMBER=22
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="pre-staged change is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/23-changed.md"
echo "- sneaky" > "${WORK}/changelog.d/1-added.md"
git -C "$WORK" add changelog.d/1-added.md
run_stage PR_NUMBER=23
if [ "$RC" -ne 0 ] && [ "$(staged)" = "$(printf 'M\tchangelog.d/1-added.md')" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="no new fragment is rejected"
new_repo
run_stage PR_NUMBER=24
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="non-numeric PR number is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/25-changed.md"
run_stage 'PR_NUMBER=../etc'
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

CASE="missing PR number is rejected"
new_repo
echo "- x" > "${WORK}/changelog.d/26-changed.md"
run_stage FOO=bar
if [ "$RC" -ne 0 ] && [ -z "$(staged)" ]; then pass; else fail "rc=${RC}: $(staged)"; fi

echo ""
echo "${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ]
