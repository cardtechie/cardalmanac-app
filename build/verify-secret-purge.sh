#!/bin/bash

# verify-secret-purge.sh - Post-rewrite gate for the #462 history purge.
#
# Takes the pre-rewrite backup mirror and the rewritten mirror and proves four
# things before the force-push:
#
#   1. Every in-scope literal that exists in the pre-rewrite history has ZERO
#      hits across all refs of the rewritten mirror.
#   2. The HEAD tree is byte-identical between the two mirrors, so the rewrite
#      provably changed history and nothing else.
#   3. Every branch and tag present before the rewrite is still present after.
#   4. Every whole file listed in REMOVED_PATHS is absent from every commit on
#      every ref of the rewritten mirror (#507). These are non-secret files
#      removed with `filter-repo --path ... --invert-paths`, which check 1's
#      literal scan cannot see.
#
# The literal set is REBUILT from the pre-rewrite mirror at verification time
# rather than read from whatever expressions file the operator happened to run
# filter-repo with. That is the whole point: #462's own warning is that a
# --replace-text file built from a stale scope table verifies itself green
# while leaving live credentials in the rewritten history. A verifier that
# trusts that file inherits the same blind spot.
#
# Rebuilding goes through build/secret-purge-expressions.sh rather than a
# second copy of the extraction logic. Two extractors would be two things to
# keep in sync, and a verifier that extracts differently from the generator
# would produce false results in both directions.
#
# NOTHING IN THIS SCRIPT PRINTS A CREDENTIAL. Findings are reported by SHA-256
# fingerprint and character count only.
#
# See docs/SECRET-HISTORY-PURGE.md for the surrounding runbook.
#
# Portability: written for bash 3.2 (the version macOS ships).

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GENERATOR="$SCRIPT_DIR/secret-purge-expressions.sh"

# Whole files removed from history by the rewrite (#507). Must match the
# `--path ... --invert-paths` list in docs/SECRET-HISTORY-PURGE.md step 4.
# Each path must already be deleted at HEAD before the rewrite runs, or
# check 2 (head-tree) fails.
REMOVED_PATHS=(
    ".claude/PROJECT-OVERVIEW.md"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [options] <pre-rewrite-mirror> <rewritten-mirror>

Post-rewrite verification gate for the #462 secret-history purge.

Arguments:
    <pre-rewrite-mirror>  The backup mirror taken before filter-repo ran
    <rewritten-mirror>    The mirror filter-repo rewrote

Options:
    -h, --help            Show this help message
    -v, --verbose         Enable verbose output

Checks (all must pass; any failure exits non-zero):
    1. literal-hits   Zero occurrences of every in-scope literal across all
                      refs of the rewritten mirror
    2. head-tree      HEAD^{tree} identical between the two mirrors
    3. refs           Every branch and tag present before is present after
    4. removed-paths  No commit on any ref of the rewritten mirror touches a
                      path listed in REMOVED_PATHS

Negative test:
    Running with the SAME mirror as both arguments MUST fail checks 1 and 4. A
    verifier that passes on an unrewritten repository is worthless -- run this
    once before trusting a green result.

Examples:
    $0 /tmp/cam-backup.git /tmp/cam-rewritten.git
    $0 /tmp/cam-backup.git /tmp/cam-backup.git   # expect FAIL on checks 1 and 4
EOF
}

# Logging functions
log_info() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*" >&2
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

fingerprint() {
    local value="$1" digest
    if command -v shasum >/dev/null 2>&1; then
        digest="$(printf '%s' "$value" | shasum -a 256 | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        digest="$(printf '%s' "$value" | sha256sum | awk '{print $1}')"
    else
        log_error "Neither shasum nor sha256sum is available; cannot fingerprint."
        exit 1
    fi
    printf '%s' "${digest:0:12}"
}

assert_mirror_clone() {
    local repo="$1" label="$2"

    if [[ ! -d "$repo" ]]; then
        log_error "$label is not a directory: $repo"
        exit 1
    fi

    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        log_error "$label is not a git repository: $repo"
        exit 1
    fi

    if [[ "$(git -C "$repo" rev-parse --is-bare-repository 2>/dev/null)" != "true" ]]; then
        log_error "$label is not a bare mirror: $repo"
        exit 1
    fi
}

WORK_DIR=""
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() {
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT INT TERM

main() {
    local pre="" post=""
    VERBOSE="${VERBOSE:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -*)
                log_error "Unknown option: $1"; usage >&2; exit 1 ;;
            *)
                if [[ -z "$pre" ]]; then pre="$1"
                elif [[ -z "$post" ]]; then post="$1"
                else log_error "Unexpected argument: $1"; exit 1
                fi
                shift ;;
        esac
    done

    if [[ -z "$pre" || -z "$post" ]]; then
        log_error "Both a pre-rewrite mirror and a rewritten mirror are required."
        usage >&2
        exit 1
    fi

    # hits.txt below holds matched credential VALUES, and the rebuilt
    # expressions file is a full credential list. Set the umask before the
    # first create so neither is briefly world-readable.
    umask 077

    assert_mirror_clone "$pre" "pre-rewrite mirror"
    assert_mirror_clone "$post" "rewritten mirror"

    if [[ ! -x "$GENERATOR" ]]; then
        log_error "Generator not found or not executable: $GENERATOR"
        exit 1
    fi

    WORK_DIR="$(mktemp -d)"
    chmod 700 "$WORK_DIR"

    echo "Pre-rewrite mirror : $pre"
    echo "Rewritten mirror   : $post"
    echo ""

    local failures=0

    # ------------------------------------------------------------------
    # Check 1: zero literal hits across all refs of the rewritten mirror
    # ------------------------------------------------------------------
    echo "== Check 1: literal hits in the rewritten history =="

    log_info "Rebuilding the literal set from the pre-rewrite mirror"
    if ! "$GENERATOR" --out "$WORK_DIR" "$pre" >"$WORK_DIR/generator.out" 2>"$WORK_DIR/generator.err"; then
        log_error "Failed to rebuild the literal set from the pre-rewrite mirror:"
        sed 's/^/    /' "$WORK_DIR/generator.err" >&2
        exit 1
    fi

    local expr_file="$WORK_DIR/replace-text.txt"
    local patterns="$WORK_DIR/patterns.txt"
    : > "$patterns"
    chmod 600 "$patterns"

    # literal:<value>==>***REMOVED***  ->  <value>
    sed -n 's/^literal:\(.*\)==>\*\*\*REMOVED\*\*\*$/\1/p' "$expr_file" > "$patterns"

    local literal_count
    literal_count="$(wc -l < "$patterns" | tr -d '[:space:]')"

    if [[ "$literal_count" -eq 0 ]]; then
        log_error "Rebuilt literal set is empty -- nothing would be verified."
        log_error "Check that '$pre' is a complete mirror of the pre-rewrite repository."
        exit 1
    fi

    echo "Literals rebuilt from the pre-rewrite mirror: $literal_count"

    # Stream every object reachable from any ref of the rewritten mirror and
    # look for all literals in one pass. Commits are included, so commit
    # messages are covered as well as file contents.
    local hits="$WORK_DIR/hits.txt"
    : > "$hits"
    chmod 600 "$hits"

    log_info "Streaming reachable objects from the rewritten mirror"
    git -C "$post" rev-list --objects --all 2>/dev/null \
        | awk '{print $1}' \
        | git -C "$post" cat-file --batch --buffer 2>/dev/null \
        | LC_ALL=C grep -F -a -o -f "$patterns" 2>/dev/null \
        | LC_ALL=C sort -u > "$hits" || true

    local hit_count
    hit_count="$(wc -l < "$hits" | tr -d '[:space:]')"

    if [[ "$hit_count" -eq 0 ]]; then
        log_pass "check 1 literal-hits: 0 of $literal_count literals appear in the rewritten history"
    else
        log_fail "check 1 literal-hits: $hit_count of $literal_count literals STILL PRESENT in the rewritten history"
        echo ""
        printf '    %-14s  %s\n' "FINGERPRINT" "CHARS"
        printf '    %-14s  %s\n' "--------------" "-----"
        local v
        while IFS= read -r v; do
            [[ -z "$v" ]] && continue
            printf '    %-14s  %s\n' "$(fingerprint "$v")" "${#v}"
        done < "$hits"
        echo ""
        echo "    Cross-reference these fingerprints with the generator's own table"
        echo "    (build/secret-purge-expressions.sh) to identify each value."
        failures=$((failures + 1))
    fi
    echo ""

    # ------------------------------------------------------------------
    # Check 2: HEAD tree unchanged
    # ------------------------------------------------------------------
    echo "== Check 2: HEAD tree identity =="

    local pre_tree post_tree
    pre_tree="$(git -C "$pre" rev-parse 'HEAD^{tree}' 2>/dev/null || echo "")"
    post_tree="$(git -C "$post" rev-parse 'HEAD^{tree}' 2>/dev/null || echo "")"

    if [[ -z "$pre_tree" || -z "$post_tree" ]]; then
        log_fail "check 2 head-tree: could not resolve HEAD^{tree} in one or both mirrors"
        echo "    pre : ${pre_tree:-<unresolved>}"
        echo "    post: ${post_tree:-<unresolved>}"
        failures=$((failures + 1))
    elif [[ "$pre_tree" == "$post_tree" ]]; then
        log_pass "check 2 head-tree: identical ($pre_tree)"
    else
        log_fail "check 2 head-tree: HEAD content CHANGED"
        echo "    pre : $pre_tree"
        echo "    post: $post_tree"
        echo "    The rewrite was supposed to touch history only. Inspect with:"
        echo "        git --git-dir='$pre' diff $pre_tree $post_tree"
        failures=$((failures + 1))
    fi
    echo ""

    # ------------------------------------------------------------------
    # Check 3: branches and tags preserved
    # ------------------------------------------------------------------
    echo "== Check 3: branches and tags preserved =="

    local pre_refs="$WORK_DIR/refs-pre.txt" post_refs="$WORK_DIR/refs-post.txt"
    git -C "$pre"  for-each-ref --format='%(refname)' refs/heads refs/tags | LC_ALL=C sort > "$pre_refs"
    git -C "$post" for-each-ref --format='%(refname)' refs/heads refs/tags | LC_ALL=C sort > "$post_refs"

    local missing extra missing_count extra_count
    missing="$(LC_ALL=C comm -23 "$pre_refs" "$post_refs")"
    extra="$(LC_ALL=C comm -13 "$pre_refs" "$post_refs")"
    missing_count="$(printf '%s' "$missing" | grep -c . || true)"
    extra_count="$(printf '%s' "$extra" | grep -c . || true)"

    if [[ "$missing_count" -eq 0 ]]; then
        log_pass "check 3 refs: all $(wc -l < "$pre_refs" | tr -d '[:space:]') branches and tags preserved"
    else
        log_fail "check 3 refs: $missing_count ref(s) present before the rewrite and missing after"
        printf '%s\n' "$missing" | sed 's/^/    /'
        failures=$((failures + 1))
    fi

    if [[ "$extra_count" -gt 0 ]]; then
        log_warn "$extra_count ref(s) exist after the rewrite but not before:"
        printf '%s\n' "$extra" | sed 's/^/    /' >&2
    fi
    echo ""

    # ------------------------------------------------------------------
    # Check 4: whole files removed from every commit on every ref
    # ------------------------------------------------------------------
    echo "== Check 4: removed paths absent from the rewritten history =="

    local path path_commits path_count survived=0
    for path in "${REMOVED_PATHS[@]}"; do
        path_commits="$(git -C "$post" log --all --format=%H -- "$path" 2>/dev/null || true)"
        path_count="$(printf '%s' "$path_commits" | grep -c . || true)"
        if [[ "$path_count" -eq 0 ]]; then
            log_info "absent from rewritten history: $path"
        else
            log_fail "check 4 removed-paths: $path is still touched by $path_count commit(s)"
            survived=$((survived + 1))
        fi
    done

    if [[ "$survived" -eq 0 ]]; then
        log_pass "check 4 removed-paths: all ${#REMOVED_PATHS[@]} path(s) absent from every ref"
    else
        echo "    Add each surviving path to the filter-repo --path ... --invert-paths"
        echo "    list in docs/SECRET-HISTORY-PURGE.md step 4 and re-run the rewrite."
        failures=$((failures + 1))
    fi
    echo ""

    # ------------------------------------------------------------------
    echo "======================================================================"
    if [[ "$failures" -eq 0 ]]; then
        log_pass "All 4 checks passed."
        echo ""
        echo "The rewritten mirror is clean of every literal derivable from the"
        echo "pre-rewrite history, its HEAD content is unchanged, no ref was lost,"
        echo "and every removed path is gone from history."
        echo ""
        log_warn "This gate proves only that the KNOWN literal set is gone. Run the"
        log_warn "independent secret scan from docs/SECRET-HISTORY-PURGE.md before"
        log_warn "treating the public-release gate as green."
        exit 0
    fi

    log_fail "$failures check(s) failed. DO NOT force-push."
    exit 1
}

main "$@"
