#!/bin/bash
#
# Tests for build/write-dependabot-fragment.sh (issue #543). Each case runs the
# real script inside a throwaway directory, so nothing touches this checkout.
#
# Usage: bash tests/build/write-dependabot-fragment.test.sh
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/build/write-dependabot-fragment.sh"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/write-dependabot-fragment-test.XXXXXX")"
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

# Run the script in a fresh directory with the given env assignments. Sets
# $WORK and $RC.
run_case() {
    WORK="$(mktemp -d "${TMP_ROOT}/case.XXXXXX")"
    RC=0
    (cd "$WORK" && env -i PATH="$PATH" "$@" bash "$SCRIPT") > "${WORK}/out.log" 2>&1 || RC=$?
}

CASE="single version update writes <pr>-changed.md"
run_case PR_NUMBER=12 DEP_NAMES=laravel/framework NEW_VERSION=12.1.0
if [ "$RC" -eq 0 ] && [ "$(cat "${WORK}/changelog.d/12-changed.md")" = "- **[PR #12]** Bump laravel/framework to 12.1.0." ]; then pass; else fail "rc=${RC}: $(cat "${WORK}"/changelog.d/* 2>&1)"; fi

CASE="advisory writes <pr>-security.md"
run_case PR_NUMBER=13 DEP_NAMES=axios NEW_VERSION=1.8.2 GHSA_ID=GHSA-abcd-1234-wxyz
if [ "$RC" -eq 0 ] && [ -f "${WORK}/changelog.d/13-security.md" ] && [ ! -f "${WORK}/changelog.d/13-changed.md" ]; then pass; else fail "rc=${RC}"; fi

CASE="group writes one line naming every dependency"
run_case PR_NUMBER=14 DEP_NAMES="vue, vuetify,@vue/cli" NEW_VERSION=3.0.0
if [ "$RC" -eq 0 ] && [ "$(cat "${WORK}/changelog.d/14-changed.md")" = "- **[PR #14]** Bump 3 dependencies: vue, vuetify, @vue/cli." ]; then pass; else fail "rc=${RC}: $(cat "${WORK}"/changelog.d/* 2>&1)"; fi

CASE="existing fragment makes it a no-op"
WORK="$(mktemp -d "${TMP_ROOT}/case.XXXXXX")"
mkdir -p "${WORK}/changelog.d"
echo "- keep me" > "${WORK}/changelog.d/15-added.md"
RC=0
(cd "$WORK" && env -i PATH="$PATH" PR_NUMBER=15 DEP_NAMES=foo NEW_VERSION=1.0.0 bash "$SCRIPT") > "${WORK}/out.log" 2>&1 || RC=$?
if [ "$RC" -eq 0 ] && [ "$(cat "${WORK}/changelog.d/15-added.md")" = "- keep me" ] && [ "$(ls "${WORK}/changelog.d" | wc -l | tr -d ' ')" = "1" ]; then pass; else fail "rc=${RC}"; fi

CASE="hostile package name is rejected"
run_case PR_NUMBER=16 'DEP_NAMES=foo$(touch pwned)' NEW_VERSION=1.0.0
if [ "$RC" -ne 0 ] && [ ! -e "${WORK}/pwned" ] && [ ! -d "${WORK}/changelog.d" ]; then pass; else fail "rc=${RC}"; fi

CASE="hostile version is rejected"
run_case PR_NUMBER=17 DEP_NAMES=foo 'NEW_VERSION=1.0.0; rm -rf /'
if [ "$RC" -ne 0 ] && [ ! -d "${WORK}/changelog.d" ]; then pass; else fail "rc=${RC}"; fi

CASE="non-numeric PR number is rejected"
run_case 'PR_NUMBER=../etc' DEP_NAMES=foo NEW_VERSION=1.0.0
if [ "$RC" -ne 0 ] && [ ! -d "${WORK}/changelog.d" ]; then pass; else fail "rc=${RC}"; fi

CASE="OUTPUT_FILE reports created and not-created"
run_case PR_NUMBER=18 DEP_NAMES=foo NEW_VERSION=1.0.0 OUTPUT_FILE="${TMP_ROOT}/o1"
first=$(cat "${TMP_ROOT}/o1")
(cd "$WORK" && env -i PATH="$PATH" PR_NUMBER=18 DEP_NAMES=foo NEW_VERSION=1.0.0 OUTPUT_FILE="${TMP_ROOT}/o2" bash "$SCRIPT") > /dev/null 2>&1
second=$(cat "${TMP_ROOT}/o2")
if [ "$first" = "created=true" ] && [ "$second" = "created=false" ]; then pass; else fail "first=${first} second=${second}"; fi

echo ""
echo "${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ]
