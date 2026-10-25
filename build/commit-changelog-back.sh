#!/bin/bash

#
# Card Almanac - Collate the changelog and commit it back (issue #542)
#
# Ported from cardtechie/cardtechie-site#505 (issue #465 there).
#
# Runs in the Build Release workflow on every push to `main`, AFTER the merge,
# so a PR never writes its own `## [X.Y.Z]` section. Collation is serialized by
# main's commit order (plus the workflow's concurrency group), which is what
# lets two open PRs never claim the same version.
#
# Steps:
#   1. build/collate-changelog.sh folds every changelog.d/ fragment into
#      `## [Unreleased]` and removes the consumed fragments.
#   2. `## [Unreleased]` is promoted to `## [VERSION] - <UTC date>` and a fresh,
#      empty `## [Unreleased]` is added above it.
#   3. CHANGELOG.md plus the fragment deletions are committed as
#      cardtechie-ops-bot[bot] with the subject
#      `chore(release): collate CHANGELOG for VERSION`, and pushed. There is
#      deliberately no `[skip ci]`: the push must start the back-merge
#      workflow so develop receives the collated CHANGELOG. Build Release
#      skips itself through its job-level guard instead.
#
# A clean no-op (exit 0, nothing committed, release=false) when nothing is
# pending. Refuses to run when CHANGELOG.md already has a `## [VERSION]`
# section, so a re-run can never write the same version twice — UNLESS that
# section was written by this script's own commit-back AND that commit is still
# HEAD, in which case a committing run RESUMES: it writes nothing and reports release=true, so a
# Build Release rerun can tag and publish a version whose commit-back already
# landed on main but whose later steps failed.
#
# Empty (whitespace-only) fragments are rejected before anything is touched.
# The collator would consume one while adding no content, and with nothing
# else pending that deletion would never be committed.
#
# `--output FILE` appends `release=true|false` to FILE (Build Release passes
# $GITHUB_OUTPUT). release=true means CHANGELOG.md at HEAD carries a
# `## [VERSION]` section to tag and publish.
#
# --no-commit is the manual / recovery path: it collates, promotes, and stages
# only, so the promotion logic lives in one place.
#
# `--is-collation-commit SUBJECT AUTHOR` exits 0 when the pair names this
# script's own commit-back. It is the canonical form of the Build Release
# self-trigger guard and is what the workflow tests pin.
#
# Bash 3.2-safe (macOS), matching build/collate-changelog.sh.
#
# Usage:
#   build/commit-changelog-back.sh VERSION [--branch BRANCH] [--no-commit] [--no-push] [--output FILE]
#   build/commit-changelog-back.sh --is-collation-commit SUBJECT AUTHOR
#

set -euo pipefail

# The anchored subject prefix and author of the commit-back. The Build Release
# self-trigger guard matches BOTH halves; a substring match on the phrase alone
# would skip collation for any human commit that merely mentions it.
COMMIT_SUBJECT_PREFIX="chore(release): collate CHANGELOG for "
# The cardtechie-ops-bot GitHub App's bot user (id from
# `gh api "/users/cardtechie-ops-bot[bot]" --jq .id`). Build Release pushes with
# that App's installation token, so the commit is attributed to the same actor.
BOT_NAME="cardtechie-ops-bot[bot]"
BOT_EMAIL="229868027+cardtechie-ops-bot[bot]@users.noreply.github.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

show_usage() {
    echo "Usage: $0 VERSION [--branch BRANCH] [--no-commit] [--no-push] [--output FILE]"
    echo "       $0 --is-collation-commit SUBJECT AUTHOR"
    echo ""
    echo "Collate changelog.d/ fragments, promote [Unreleased] to [VERSION] - DATE,"
    echo "and commit the result back to BRANCH (default: main)."
    echo ""
    echo "  --branch BRANCH   Branch to push the commit-back to (default: main)"
    echo "  --no-commit       Collate, promote, and stage only; do not commit"
    echo "  --no-push         Commit but do not push"
    echo "  --output FILE     Append release=true|false to FILE (e.g. \$GITHUB_OUTPUT)"
}

if [[ "${1:-}" == "--is-collation-commit" ]]; then
    if [[ $# -ne 3 ]]; then
        echo "❌ Error: --is-collation-commit takes SUBJECT and AUTHOR" >&2
        exit 2
    fi
    if [[ "$2" == "${COMMIT_SUBJECT_PREFIX}"* && "$3" == "$BOT_NAME" ]]; then
        exit 0
    fi
    exit 1
fi

VERSION=""
BRANCH="main"
DO_COMMIT=true
DO_PUSH=true
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "❌ Error: --branch requires a value" >&2
                exit 1
            fi
            BRANCH="$2"
            shift 2
            ;;
        --no-commit)
            DO_COMMIT=false
            shift
            ;;
        --no-push)
            DO_PUSH=false
            shift
            ;;
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
        -*)
            echo "❌ Error: Unknown argument '$1'" >&2
            show_usage >&2
            exit 1
            ;;
        *)
            if [[ -n "$VERSION" ]]; then
                echo "❌ Error: unexpected extra argument '$1'" >&2
                exit 1
            fi
            VERSION="$1"
            shift
            ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "❌ Error: VERSION is required" >&2
    show_usage >&2
    exit 1
fi

# Plain semver with an optional pre-release suffix. It also keeps the version
# safe to interpolate into the sed expressions below.
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9-]+(\.[0-9]+)?)?$ ]]; then
    echo "❌ Error: Invalid version format: $VERSION" >&2
    exit 1
fi

# Resolve a relative --output against the caller's directory before the cd.
if [[ -n "$OUTPUT_FILE" && "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="${PWD}/${OUTPUT_FILE}"
fi

# Record whether HEAD carries a `## [VERSION]` section to tag and publish.
write_result() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "release=$1" >> "$OUTPUT_FILE"
    fi
}

cd "$PROJECT_ROOT"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository" >&2
    exit 1
fi

CHANGELOG_FILE="CHANGELOG.md"
if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo "❌ Error: ${CHANGELOG_FILE} not found" >&2
    exit 1
fi

# True when HEAD itself is this script's own commit-back for VERSION. Only the
# branch tip counts: if anything landed after the commit-back, HEAD carries
# later code and fragments that VERSION's notes do not describe, so tagging it
# as VERSION would mislabel the release.
#
# Author name and subject are free text anyone can put on a commit, so they
# are a pre-filter only. What makes a resume safe is the commit's CONTENT:
#   - HEAD has exactly one parent and that parent has no `## [VERSION]`
#     section, i.e. HEAD is the commit that introduced it (a PR cannot: the
#     Changelog Fragment gate rejects any PR that adds a version heading); and
#   - HEAD touches nothing outside CHANGELOG.md and changelog.d/, so tagging
#     it releases exactly its parent's code plus the notes, which is what the
#     failed run would have released.
head_is_own_collation_commit() {
    local author subject parents path
    IFS=$'\t' read -r author subject < <(git log -1 --format='%an%x09%s' HEAD 2>/dev/null) || return 1
    [[ "$author" == "$BOT_NAME" && "$subject" == "${COMMIT_SUBJECT_PREFIX}${VERSION}" ]] || return 1

    parents=$(git rev-list --parents -n 1 HEAD 2>/dev/null | wc -w | tr -d ' ')
    [[ "$parents" == "2" ]] || return 1
    # Read the parent's changelog into a variable first rather than piping
    # `git show` into `grep -q`: under pipefail, grep's early exit can SIGPIPE
    # git show, the pipeline returns 141, and the check would read as "parent
    # lacks the section" exactly when it has it.
    local parent_changelog
    parent_changelog=$(git show "HEAD^:${CHANGELOG_FILE}" 2>/dev/null) || return 1
    if grep -q "^## \[${VERSION_RE}\]" <<< "$parent_changelog"; then
        return 1
    fi

    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        case "$path" in
            "$CHANGELOG_FILE"|changelog.d/*) ;;
            *) return 1 ;;
        esac
    done < <(git diff-tree --no-commit-id --name-only -r HEAD^ HEAD)
    return 0
}

# Escape the dots so `0.2.1` cannot match `0x2y1`.
VERSION_RE="${VERSION//./\\.}"
if grep -q "^## \[${VERSION_RE}\]" "$CHANGELOG_FILE"; then
    # Resume: an earlier run committed (and pushed) this section, then failed
    # before tagging. Re-collating is refused, but the section is ours, so the
    # release can go ahead from HEAD. Fragments merged since stay pending for
    # the next version. The manual --no-commit path keeps the hard refusal.
    if [[ "$DO_COMMIT" == "true" ]] && head_is_own_collation_commit; then
        echo "♻️  ${CHANGELOG_FILE} already has the '## [${VERSION}]' section from an earlier commit-back at HEAD — resuming the release without re-collating."
        write_result true
        exit 0
    fi
    echo "❌ Error: ${CHANGELOG_FILE} already has a '## [${VERSION}]' section — refusing to write it twice." >&2
    if [[ "$DO_COMMIT" == "true" ]]; then
        echo "   A resume only runs when HEAD is that version's own commit-back. If ${BRANCH}" >&2
        echo "   moved past it, tag and release that commit-back by hand instead of re-running." >&2
    fi
    exit 1
fi

# Reject fragments with no release-note content BEFORE the collator touches
# anything: an empty file, or one holding only blank lines and headings (e.g. a
# bare `### Added`). The collator would consume it while adding no content;
# with nothing else pending, [Unreleased] stays empty (the count below ignores
# headings), the no-op path returns without committing, and the deletion never
# reaches main, so every later push repeats the same no-op.
shopt -s nullglob
EMPTY_FRAGMENTS=()
NON_REGULAR=()
for frag in changelog.d/*.md; do
    [[ "$(basename "$frag")" == "README.md" ]] && continue
    # A symlink (or any non-regular path) named like a fragment would be
    # followed by the reads below and by the collator, committing whatever it
    # points at into CHANGELOG.md and the release notes. -L first: -f follows
    # symlinks. collate-changelog.sh carries the same guard for direct callers.
    if [[ -L "$frag" || ! -f "$frag" ]]; then
        NON_REGULAR+=("$frag")
        continue
    fi
    # Single-stream check: a `grep | grep -q` pipeline under pipefail can
    # SIGPIPE the first grep when grep -q exits early, misreading a valid
    # fragment as empty. awk reads the whole file before deciding.
    if ! awk '!/^[[:space:]]*#/ && /[^[:space:]]/ { found = 1 } END { exit !found }' "$frag"; then
        EMPTY_FRAGMENTS+=("$frag")
    fi
done
shopt -u nullglob
if [[ ${#NON_REGULAR[@]} -gt 0 ]]; then
    echo "❌ Error: changelog fragment(s) that are not regular files (symlink or other): ${NON_REGULAR[*]}" >&2
    echo "   Replace each with a plain file holding its changelog line, then re-run." >&2
    exit 1
fi
if [[ ${#EMPTY_FRAGMENTS[@]} -gt 0 ]]; then
    echo "❌ Error: changelog fragment(s) with no release-note line: ${EMPTY_FRAGMENTS[*]}" >&2
    echo "   Give each one a changelog line (e.g. '- **[Issue #N]** ...'), or delete it, then re-run." >&2
    exit 1
fi

echo "🔁 Collating the changelog for ${VERSION}"

# Invoke via `bash` so a lost exec bit cannot silently skip collation.
bash "${PROJECT_ROOT}/build/collate-changelog.sh"

# Do not trust the collator's exit status alone: bash 3.2 exits 0 on a syntax
# error partway through a script, which is exactly how a broken collator once
# reported success while consuming nothing. A fragment that survives
# collation is a failure, never a no-op.
shopt -s nullglob
LEFTOVER=()
for frag in changelog.d/*.md; do
    [[ "$(basename "$frag")" == "README.md" ]] && continue
    LEFTOVER+=("$frag")
done
shopt -u nullglob
if [[ ${#LEFTOVER[@]} -gt 0 ]]; then
    echo "❌ Error: ${#LEFTOVER[@]} fragment(s) survived collation: ${LEFTOVER[*]}" >&2
    exit 1
fi

# Count content lines only: blank lines and headings (e.g. a `### Added` left
# with no bullets under it) are not release notes, so a heading-only section
# is still a clean no-op rather than an empty release.
UNRELEASED_LINES=$(sed -n '/^## \[Unreleased\]/,/^## \[/p' "$CHANGELOG_FILE" | sed '1d' | grep -v '^#' | grep -cv '^[[:space:]]*$' || true)
if [[ "$UNRELEASED_LINES" -eq 0 ]]; then
    echo "ℹ️  [Unreleased] is empty after collation — nothing to release-note (clean no-op)."
    write_result false
    exit 0
fi

RELEASE_DATE=$(date -u +%Y-%m-%d)
echo "📝 Promoting [Unreleased] → [${VERSION}] - ${RELEASE_DATE}"

# Promote only the FIRST [Unreleased] heading, then put a fresh empty one above
# it. sed -i.tmp is the portable in-place form for both GNU and BSD sed.
sed -i.tmp "1,/^## \[Unreleased\]/s/^## \[Unreleased\]/## [${VERSION}] - ${RELEASE_DATE}/" "$CHANGELOG_FILE"
sed -i.tmp "/^## \[${VERSION_RE}\] - ${RELEASE_DATE}/i\\
## [Unreleased]\\
" "$CHANGELOG_FILE"
rm -f "${CHANGELOG_FILE}.tmp"

# When committing, clear the index first so nothing a caller staged earlier
# rides along in the commit-back. Under --no-commit (the manual / recovery
# path) the caller's index is left alone: the changelog and fragment deletions
# are staged on top of whatever they already staged. `git add -A` on the
# directory captures the deletions however the collator removed the files.
if [[ "$DO_COMMIT" == "true" ]] && git rev-parse --verify --quiet HEAD > /dev/null; then
    git reset -q
fi
git add -A -- "$CHANGELOG_FILE"
if [[ -e changelog.d ]] || git ls-files --error-unmatch changelog.d > /dev/null 2>&1; then
    git add -A -- changelog.d
fi

if [[ "$DO_COMMIT" != "true" ]]; then
    echo "⏭️  --no-commit: collated, promoted, and staged only."
    exit 0
fi

git -c user.name="$BOT_NAME" -c user.email="$BOT_EMAIL" \
    commit --quiet -m "${COMMIT_SUBJECT_PREFIX}${VERSION}"
echo "✅ Committed the collated CHANGELOG for ${VERSION}."

if [[ "$DO_PUSH" == "true" ]]; then
    # No `|| true`: a refused push (e.g. branch protection on main) must fail
    # the release loudly rather than ship a release with no notes.
    if ! git push origin "HEAD:${BRANCH}"; then
        echo "❌ Error: the changelog commit-back push to ${BRANCH} was rejected." >&2
        echo "   The release is NOT tagged or published, so it never ships without notes." >&2
        echo "   Most likely cause: the ${BRANCH} ruleset does not list the cardtechie-ops-bot" >&2
        echo "   App as a bypass actor, or ${BRANCH} moved (non-fast-forward). Fix that and" >&2
        echo "   re-run the Build Release workflow." >&2
        exit 1
    fi
    echo "✅ Pushed the commit-back to ${BRANCH}."
else
    echo "⏭️  --no-push: committed only, not pushing."
fi
write_result true
