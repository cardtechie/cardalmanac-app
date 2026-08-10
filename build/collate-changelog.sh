#!/bin/bash

#
# Collate changelog.d/*.md fragments into the "## [Unreleased]" section of
# CHANGELOG.md, grouped under the matching "### <Type>" heading, then delete the
# consumed fragments. Runs ahead of update-changelog.sh in the release path so
# the Unreleased section reflects every fragment before the release step runs.
# Note: the version cut is update-changelog.sh, which inserts the new
# "## [<version>] - <date>" heading directly below "## [Unreleased]" — so the
# bullets collated here become the body of the new version section and
# [Unreleased] is left empty for the next cycle. The `update` action (used by
# `make changelog-update`) additionally generates bullets from git commit
# messages and inserts them above the collated content, so that path
# concatenates both sources under the version heading; de-duplicating
# commit-derived bullets against fragment-derived ones is tracked separately.
# The `finalize` action (used by `make release-prepare`) relocates the collated
# content only, with no commit-derived bullets.
#
# Per-PR fragments live at changelog.d/<issue>-<type>.md where <type> is one of
# added | changed | deprecated | removed | fixed | security (canonical
# Keep-a-Changelog order; see VALID_TYPES below). Each fragment body
# is one or more Keep-a-Changelog list lines (a `- ...` bullet plus optional
# indented caveat sub-bullets); the type comes from the filename, not the body.
#
# Idempotent: a clean no-op when changelog.d/ holds no fragments. Output
# respects MD024 { siblings_only: true } by merging into an existing same-type
# subsection rather than duplicating headings.
#
# --preview mode is non-destructive: it collates into a scratch copy of the
# changelog, prints the resulting "## [Unreleased]" section to stdout, and
# leaves CHANGELOG.md and the fragments untouched. `make changelog-preview`
# uses it to show what the next release's Unreleased section will contain.
#
# Avoids bash 4 associative arrays (macOS ships bash 3.2) — buckets are six
# plain variables keyed by the fixed type set.
#
# Usage: build/collate-changelog.sh [--changelog FILE] [--fragments-dir DIR] [--preview]
#

set -euo pipefail

CHANGELOG_FILE="CHANGELOG.md"
FRAGMENTS_DIR="changelog.d"
PREVIEW=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --changelog)
            CHANGELOG_FILE="$2"
            shift 2
            ;;
        --fragments-dir)
            FRAGMENTS_DIR="$2"
            shift 2
            ;;
        --preview|-p)
            PREVIEW=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--changelog FILE] [--fragments-dir DIR] [--preview]"
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown argument '$1'" >&2
            exit 1
            ;;
    esac
done

# The fixed Keep-a-Changelog type set. Order here is the canonical subsection
# order used when creating a missing subsection.
VALID_TYPES="added changed deprecated removed fixed security"

# Per-type accumulators (avoid associative arrays for bash 3.2 portability).
BUCKET_ADDED=""
BUCKET_CHANGED=""
BUCKET_DEPRECATED=""
BUCKET_REMOVED=""
BUCKET_FIXED=""
BUCKET_SECURITY=""

# Append a body to the bucket variable for a given type.
append_bucket() {
    local type="$1" body="$2" sep=""
    case "$type" in
        added)      [[ -n "$BUCKET_ADDED" ]] && sep=$'\n';      BUCKET_ADDED="${BUCKET_ADDED}${sep}${body}" ;;
        changed)    [[ -n "$BUCKET_CHANGED" ]] && sep=$'\n';    BUCKET_CHANGED="${BUCKET_CHANGED}${sep}${body}" ;;
        deprecated) [[ -n "$BUCKET_DEPRECATED" ]] && sep=$'\n'; BUCKET_DEPRECATED="${BUCKET_DEPRECATED}${sep}${body}" ;;
        removed)    [[ -n "$BUCKET_REMOVED" ]] && sep=$'\n';    BUCKET_REMOVED="${BUCKET_REMOVED}${sep}${body}" ;;
        fixed)      [[ -n "$BUCKET_FIXED" ]] && sep=$'\n';      BUCKET_FIXED="${BUCKET_FIXED}${sep}${body}" ;;
        security)   [[ -n "$BUCKET_SECURITY" ]] && sep=$'\n';   BUCKET_SECURITY="${BUCKET_SECURITY}${sep}${body}" ;;
    esac
}

is_valid_type() {
    local t="$1" v
    for v in $VALID_TYPES; do
        [[ "$t" == "$v" ]] && return 0
    done
    return 1
}

# Nothing to do if the fragments directory is missing or holds no *.md files.
shopt -s nullglob
ALL_MD=("$FRAGMENTS_DIR"/*.md)
shopt -u nullglob

# README.md is documentation, not a fragment — never collate or delete it.
FRAGMENTS=()
for frag in ${ALL_MD[@]+"${ALL_MD[@]}"}; do
    [[ "$(basename "$frag")" == "README.md" ]] && continue
    FRAGMENTS+=("$frag")
done

if [[ ${#FRAGMENTS[@]} -eq 0 ]]; then
    echo "ℹ️  No changelog fragments in ${FRAGMENTS_DIR}/ — nothing to collate."
    exit 0
fi

if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo "❌ Error: ${CHANGELOG_FILE} not found" >&2
    exit 1
fi

# Fail fast if the changelog has no "## [Unreleased]" section. Without it the awk
# pass below never enters in_unreleased, so the bucketed fragment content is
# silently dropped — yet the destructive path still cp's the unchanged file and
# git rm's the fragments, losing their entries. Refuse before touching anything
# (guards both --preview and real runs against a wrong --changelog / format drift).
if ! grep -q '^## \[Unreleased\]' "$CHANGELOG_FILE"; then
    echo "❌ Error: ${CHANGELOG_FILE} has no '## [Unreleased]' section — refusing to collate (fragments would be deleted without being recorded)." >&2
    exit 1
fi

if [[ "$PREVIEW" == "true" ]]; then
    echo "🔎 Previewing collation of ${#FRAGMENTS[@]} changelog fragment(s) (no files changed)..."
else
    echo "📋 Collating ${#FRAGMENTS[@]} changelog fragment(s) into ${CHANGELOG_FILE}..."
fi

CONSUMED=()
for frag in "${FRAGMENTS[@]}"; do
    base="$(basename "$frag" .md)"
    # Filename shape: <issue>-<type>. The type is the final dash-delimited token.
    type="$(printf '%s' "${base##*-}" | tr '[:upper:]' '[:lower:]')"

    if ! is_valid_type "$type"; then
        echo "❌ Error: fragment '${frag}' has unrecognized type '${type}'." >&2
        echo "   Expected <issue>-<type>.md with type in: ${VALID_TYPES}" >&2
        exit 1
    fi

    # Strip a single trailing blank line (empty or whitespace-only); keep
    # interior structure (sub-bullets). Matching whitespace-only avoids leaving a
    # trailing spaces line in the collated CHANGELOG when an editor pads the
    # fragment's final line (the MD012 collapse pass only catches fully-empty lines).
    body="$(sed -e '${/^[[:space:]]*$/d;}' "$frag")"
    if [[ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]]; then
        echo "⚠️  Fragment '${frag}' is empty — consuming it without adding content." >&2
    else
        append_bucket "$type" "$body"
    fi
    CONSUMED+=("$frag")
done

# Rebuild CHANGELOG.md: walk the Unreleased section, append bucketed lines into
# the matching existing ### subsection, and create any missing subsections at
# the end of the Unreleased block in canonical order.
# Use an explicit template (portable across GNU and macOS/BSD mktemp, which
# diverge on how a bare `-t` prefix is interpreted).
TEMP_OUT="$(mktemp "${TMPDIR:-/tmp}/collate-changelog.XXXXXX")"
COLLATED="$(mktemp "${TMPDIR:-/tmp}/collate-changelog.XXXXXX")"
trap 'rm -f "$TEMP_OUT" "$COLLATED"' EXIT

# Export buckets so awk can read them via ENVIRON[] (avoids quoting hazards from
# passing multi-line bodies as -v assignments).
export BUCKET_ADDED BUCKET_CHANGED BUCKET_DEPRECATED BUCKET_REMOVED BUCKET_FIXED BUCKET_SECURITY

awk '
function title_case(s) {
    return toupper(substr(s, 1, 1)) substr(s, 2)
}
# Emit the buffered lines of the current subsection (heading + existing body),
# then append this types new bullets, then a single trailing blank line. Trailing
# blank lines in the buffer are dropped so the appended bullets stay contiguous
# with the existing list (one list, not two), keeping the result MD032/MD012-clean.
function flush_subsection(   i, last) {
    if (!have_sub) return
    # Find the last non-blank buffered line.
    last = sub_n
    while (last > 0 && sub_buf[last] ~ /^[[:space:]]*$/) last--
    for (i = 1; i <= last; i++) print sub_buf[i]
    if (cur_type != "" && (cur_type in additions)) {
        printf "%s\n", additions[cur_type]
        delete additions[cur_type]
    }
    print ""   # exactly one blank line after the subsection
    have_sub = 0
    sub_n = 0
    cur_type = ""
}
function create_missing(   i, t) {
    # Emit any still-unconsumed subsections, in canonical order.
    for (i = 1; i <= 6; i++) {
        t = order[i]
        if (t in additions) {
            printf "### %s\n\n", title_case(t)
            printf "%s\n\n", additions[t]
            delete additions[t]
        }
    }
}
BEGIN {
    in_unreleased = 0
    have_sub = 0
    sub_n = 0
    cur_type = ""
    split("added changed deprecated removed fixed security", order, " ")
    if (ENVIRON["BUCKET_ADDED"]      != "") additions["added"]      = ENVIRON["BUCKET_ADDED"]
    if (ENVIRON["BUCKET_CHANGED"]    != "") additions["changed"]    = ENVIRON["BUCKET_CHANGED"]
    if (ENVIRON["BUCKET_DEPRECATED"] != "") additions["deprecated"] = ENVIRON["BUCKET_DEPRECATED"]
    if (ENVIRON["BUCKET_REMOVED"]    != "") additions["removed"]    = ENVIRON["BUCKET_REMOVED"]
    if (ENVIRON["BUCKET_FIXED"]      != "") additions["fixed"]      = ENVIRON["BUCKET_FIXED"]
    if (ENVIRON["BUCKET_SECURITY"]   != "") additions["security"]   = ENVIRON["BUCKET_SECURITY"]
}
/^## \[Unreleased\]/ {
    print
    in_unreleased = 1
    next
}
in_unreleased == 1 && /^## \[/ {
    # Leaving Unreleased: flush the active subsection, then create missing ones.
    flush_subsection()
    create_missing()
    in_unreleased = 0
    print
    next
}
in_unreleased == 1 && /^### / {
    # New subsection heading: flush the prior subsection, then start buffering
    # this one (heading is buffered as line 1 of the new subsection).
    flush_subsection()
    have_sub = 1
    sub_n = 1
    sub_buf[1] = $0
    heading = $0
    sub(/^### /, "", heading)
    cur_type = tolower(heading)
    next
}
in_unreleased == 1 && have_sub == 1 {
    # Buffer body lines of the active subsection.
    sub_n++
    sub_buf[sub_n] = $0
    next
}
{
    print
}
END {
    if (in_unreleased == 1) {
        flush_subsection()
        create_missing()
    }
}
' "$CHANGELOG_FILE" > "$TEMP_OUT"

# Collapse any run of blank lines to a single blank line so the inserted content
# stays MD012-clean even when a subsection already ended with a blank line
# before our appended bullets.
awk '/^$/ { if (blank++ < 1) print; next } { blank = 0; print }' "$TEMP_OUT" > "$COLLATED"

if [[ "$PREVIEW" == "true" ]]; then
    # Non-destructive: print the resulting Unreleased section and leave the real
    # CHANGELOG.md and the fragments in place.
    echo ""
    echo "──────── preview: ## [Unreleased] after collation ────────"
    awk '
        /^## \[Unreleased\]/ { in_u = 1; print; next }
        in_u == 1 && /^## \[/ { in_u = 0 }
        in_u == 1 { print }
    ' "$COLLATED"
    echo "──────────────────────────────────────────────────────────"
    echo ""
    echo "ℹ️  Preview only — CHANGELOG.md and ${FRAGMENTS_DIR}/ fragments were not modified."
    exit 0
fi

cp "$COLLATED" "$CHANGELOG_FILE"
rm -f "$TEMP_OUT" "$COLLATED"
trap - EXIT

# Remove the consumed fragments. Use git rm when the file is tracked so the
# deletion is staged for the release commit; fall back to plain rm otherwise.
for frag in "${CONSUMED[@]}"; do
    if git ls-files --error-unmatch "$frag" >/dev/null 2>&1; then
        # -f because the fragment's body has already been captured into the
        # CHANGELOG; we intentionally discard the file regardless of index state.
        git rm --quiet -f "$frag"
    else
        rm -f "$frag"
    fi
done

echo "✅ Collated ${#CONSUMED[@]} fragment(s) into ${CHANGELOG_FILE} and removed them from ${FRAGMENTS_DIR}/."
