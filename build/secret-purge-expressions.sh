#!/bin/bash

# secret-purge-expressions.sh - Build the git filter-repo --replace-text
# expressions file for the history purge described in #462.
#
# Reads every historical revision of the four files that ever carried a
# credential, extracts the literal assignment values, drops variable
# references and anything the repository's own gitleaks allowlist declares
# not-a-credential, and writes one `literal:<value>==>***REMOVED***` line per
# distinct value into a gitignored scratch directory.
#
# The generated file is a plaintext list of live credentials. It is written
# with mode 0600 into /.secret-purge/, which .gitignore excludes, and it must
# never be committed, pasted into an issue, or attached to a CI job.
#
# NOTHING IN THIS SCRIPT PRINTS A CREDENTIAL. Values are reported by SHA-256
# fingerprint and character count only.
#
# See docs/SECRET-HISTORY-PURGE.md for the surrounding runbook.
#
# Portability: written for bash 3.2 (the version macOS ships) -- no
# associative arrays, no ${var^^}. Aggregation goes through awk instead.

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_OUT_DIR="$PROJECT_ROOT/.secret-purge"
GITLEAKS_CONFIG="$PROJECT_ROOT/.gitleaks.toml"

# Values shorter than this are reported but NOT written to the expressions
# file. The in-scope keys include DB_HOST and DB_USERNAME, and in the dev
# compose files those hold service names and 'root' -- a literal rewrite of a
# 4-to-5 character token replaces every other occurrence of it in history too,
# which is far more damaging than leaving a non-secret in place.
DEFAULT_MIN_LENGTH=8

# Paths that have ever carried a credential in this repository (#462 scope
# table). History is walked for each; a path that no longer exists at HEAD is
# still walked, because the whole point is that the values are historical.
SCOPE_PATHS=(
    ".docker/prod.docker-compose.yaml"
    ".docker/docker-compose.full.yml"
    ".docker/dusk.docker-compose.yaml"
    ".env.local"
)

# Assignment keys whose values are in scope. Covers the DigitalOcean cluster
# coordinates (host/user/database) as well as the passwords and keys, because
# the #462 scope table lists them.
SCOPE_KEYS="APP_KEY DB_PASSWORD DB_USERNAME DB_HOST DB_DATABASE CARDS_DB_PASSWORD CARDS_DB_USERNAME CARDS_DB_HOST CARDS_DB_DATABASE MAILGUN_SECRET TRADINGCARDAPI_CLIENT_ID TRADINGCARDAPI_CLIENT_SECRET"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [options] <mirror-clone-path>

Builds the git filter-repo --replace-text expressions file for #462 from the
history of a MIRROR clone.

Arguments:
    <mirror-clone-path>   Path to a bare mirror clone:
                              git clone --mirror git@github.com:cardtechie/cardalmanac-app.git

Options:
    -h, --help            Show this help message
    -o, --out DIR         Output directory [default: <repo>/.secret-purge]
    -m, --min-length N    Minimum value length to treat as a credential
                          [default: $DEFAULT_MIN_LENGTH]
    -v, --verbose         Enable verbose output

Output:
    <out>/replace-text.txt   mode 0600, one 'literal:<value>==>***REMOVED***'
                             line per distinct credential.

What is EXCLUDED, and why:
    present-at-head   The value still exists in the mirror's HEAD tree. HEAD is
                      clean of credentials (#462 re-scoping), so a surviving
                      value is a dev default -- a service name, a database
                      name, the literal 'password'. Rewriting it would corrupt
                      unrelated history.
    too-short         Shorter than --min-length. DB_HOST and DB_USERNAME hold
                      things like a compose service name and 'root' in the dev
                      files; a literal rewrite of those is catastrophic.
    gitleaks-allowlist  Matched an allowlist regex in .gitleaks.toml.

    Every exclusion is reported with its fingerprint, never silently dropped.
    To force one back in, add its 'literal:<value>==>***REMOVED***' line to the
    expressions file by hand.

Safety:
    - Refuses to run against a non-bare clone, so it can never be pointed at a
      live working checkout.
    - Never prints a credential. Values are reported by truncated SHA-256
      fingerprint and character count only.
    - The output file is a plaintext credential list. Keep it out of the repo,
      out of CI logs, and delete it when the purge is verified.

Examples:
    git clone --mirror git@github.com:cardtechie/cardalmanac-app.git /tmp/cam.git
    $0 /tmp/cam.git
    $0 --out /tmp/purge /tmp/cam.git
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

log_success() {
    echo -e "${GREEN}[OK]${NC} $*" >&2
}

# Truncated SHA-256 fingerprint of a value. This is the ONLY representation of
# a credential this script is allowed to emit.
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

# Verify the argument is a bare mirror clone, not a working checkout.
assert_mirror_clone() {
    local repo="$1"

    if [[ ! -d "$repo" ]]; then
        log_error "Not a directory: $repo"
        exit 1
    fi

    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not a git repository: $repo"
        exit 1
    fi

    if [[ "$(git -C "$repo" rev-parse --is-bare-repository 2>/dev/null)" != "true" ]]; then
        log_error "Refusing to run against a non-bare repository: $repo"
        log_error "Take a mirror clone first:"
        log_error "    git clone --mirror git@github.com:cardtechie/cardalmanac-app.git <path>"
        exit 1
    fi
}

# Translate the gitleaks allowlist regexes into POSIX ERE that grep -E can use.
#
# The allowlist in .gitleaks.toml is written in Go's RE2 syntax. The entries it
# currently holds need exactly two translations: a leading inline
# case-insensitivity flag (handled by grep -Ei instead) and the \s shorthand.
# A regex that survives translation but grep still rejects is a HARD ERROR
# rather than a skip -- silently dropping an allowlist entry would put the
# literal dev password 'password' on the replacement list, and rewriting that
# string across all of history is exactly the collateral damage the allowlist
# exists to prevent.
ALLOWLIST_REGEXES=()

load_allowlist_regexes() {
    ALLOWLIST_REGEXES=()

    if [[ ! -f "$GITLEAKS_CONFIG" ]]; then
        log_warn "No .gitleaks.toml at $GITLEAKS_CONFIG; proceeding with no value allowlist."
        return 0
    fi

    local raw translated status
    while IFS= read -r raw; do
        [[ -z "$raw" ]] && continue
        translated="${raw//\\s/[[:space:]]}"

        # grep exits 0 on match, 1 on no match (expected against empty input),
        # and 2 on an invalid pattern. Capture the status directly -- reading
        # $? inside an `if !` body would report the negation, not grep.
        status=0
        printf '%s' "" | grep -Eiq "$translated" 2>/dev/null || status=$?
        if [[ "$status" -gt 1 ]]; then
            log_error "Could not translate this gitleaks allowlist regex to POSIX ERE:"
            log_error "    $raw"
            log_error "Extend the translation in $(basename "$0") before running the purge;"
            log_error "skipping it would put an allowlisted value on the replacement list."
            exit 1
        fi

        ALLOWLIST_REGEXES=("${ALLOWLIST_REGEXES[@]+"${ALLOWLIST_REGEXES[@]}"}" "$translated")
    done < <(
        awk '
            /^\[allowlist\]/ { in_allowlist = 1; next }
            /^\[/            { in_allowlist = 0 }
            in_allowlist && /^[[:space:]]*regexes[[:space:]]*=/ { in_regexes = 1; next }
            in_regexes && /^[[:space:]]*\]/ { in_regexes = 0 }
            in_regexes {
                line = $0
                sub(/^[[:space:]]*/, "", line)
                if (line ~ /^#/) next
                if (line !~ /^'"'''"'/) next
                sub(/^'"'''"'/, "", line)
                sub(/'"'''"',?[[:space:]]*$/, "", line)
                # Strip a leading RE2 inline case-insensitivity flag; grep -Ei
                # supplies the same behaviour.
                sub(/^\(\?i\)/, "", line)
                if (length(line) > 0) print line
            }
        ' "$GITLEAKS_CONFIG"
    )

    log_info "Loaded ${#ALLOWLIST_REGEXES[@]} allowlist regex(es) from .gitleaks.toml"
}

is_allowlisted() {
    local key="$1" value="$2" re
    for re in "${ALLOWLIST_REGEXES[@]+"${ALLOWLIST_REGEXES[@]}"}"; do
        if printf '%s\n%s\n' "$key: $value" "$key=$value" | grep -Eiq "$re"; then
            return 0
        fi
    done
    return 1
}

# Emit "KEY<TAB>VALUE" for every in-scope assignment in the content on stdin.
# Handles both the dotenv (KEY=value) and YAML (KEY: value) forms this
# repository actually uses, with or without surrounding quotes.
extract_assignments() {
    awk -v keys="$SCOPE_KEYS" '
        BEGIN {
            n = split(keys, k, " ")
            for (i = 1; i <= n; i++) want[k[i]] = 1
        }
        {
            line = $0
            sub(/\r$/, "", line)
            sub(/^[[:space:]]*/, "", line)
            if (line ~ /^#/) next

            if (!match(line, /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[:=]/)) next

            key = substr(line, 1, RLENGTH - 1)
            gsub(/[[:space:]]/, "", key)
            if (!(toupper(key) in want)) next

            val = substr(line, RLENGTH + 1)
            sub(/^[[:space:]]+/, "", val)
            sub(/[[:space:]]+$/, "", val)

            # Strip one layer of matching surrounding quotes.
            if (length(val) >= 2) {
                first = substr(val, 1, 1)
                last  = substr(val, length(val), 1)
                if ((first == "\"" && last == "\"") || (first == "'"'"'" && last == "'"'"'")) {
                    val = substr(val, 2, length(val) - 2)
                }
            }

            if (length(val) == 0) next
            # A tab would collide with the field separator used downstream.
            if (index(val, "\t") > 0) next
            printf "%s\t%s\n", toupper(key), val
        }
    '
}

SCRATCH_DIR=""
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() {
    if [[ -n "$SCRATCH_DIR" && -d "$SCRATCH_DIR" ]]; then
        rm -f "$SCRATCH_DIR/.pairs.$$" "$SCRATCH_DIR/.agg.$$" \
              "$SCRATCH_DIR/.head.$$" "$SCRATCH_DIR/.skipped.$$"
    fi
}
trap cleanup EXIT INT TERM

main() {
    local mirror="" out_dir="$DEFAULT_OUT_DIR" min_length="$DEFAULT_MIN_LENGTH"
    VERBOSE="${VERBOSE:-false}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    usage; exit 0 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -o|--out)
                if [[ $# -lt 2 ]]; then log_error "--out requires a directory"; exit 1; fi
                out_dir="$2"; shift 2 ;;
            -m|--min-length)
                if [[ $# -lt 2 ]]; then log_error "--min-length requires a number"; exit 1; fi
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then log_error "--min-length must be a non-negative integer: $2"; exit 1; fi
                min_length="$2"; shift 2 ;;
            -*)
                log_error "Unknown option: $1"; usage >&2; exit 1 ;;
            *)
                if [[ -n "$mirror" ]]; then log_error "Unexpected argument: $1"; exit 1; fi
                mirror="$1"; shift ;;
        esac
    done

    if [[ -z "$mirror" ]]; then
        log_error "A mirror-clone path is required."
        usage >&2
        exit 1
    fi

    # Everything this script writes is credential-bearing. Set the umask before
    # the first create so no file is ever briefly world-readable between its
    # creation and its chmod.
    umask 077

    assert_mirror_clone "$mirror"
    load_allowlist_regexes

    local out_file="$out_dir/replace-text.txt"
    mkdir -p "$out_dir"
    chmod 700 "$out_dir" 2>/dev/null || true

    # Collect VALUE<TAB>KEY pairs into a 0600 scratch file. A file rather than a
    # shell array both keeps bash 3.2 compatibility and keeps credentials out of
    # the process environment.
    SCRATCH_DIR="$out_dir"
    local pairs_file="$out_dir/.pairs.$$"
    : > "$pairs_file"
    chmod 600 "$pairs_file"

    local path rev blob key value line scanned_blobs=0

    for path in "${SCOPE_PATHS[@]}"; do
        log_info "Walking history for $path"
        while IFS= read -r rev; do
            [[ -z "$rev" ]] && continue
            blob="$(git -C "$mirror" show "$rev:$path" 2>/dev/null || true)"
            [[ -z "$blob" ]] && continue
            scanned_blobs=$((scanned_blobs + 1))
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                key="${line%%$'\t'*}"
                value="${line#*$'\t'}"

                # Variable references and command substitutions are not values.
                # shellcheck disable=SC2016  # the single quotes are deliberate: these are literal patterns, not expansions
                case "$value" in
                    *'${'*|*'$('*) continue ;;
                esac

                # The replace-text format uses '==>' as its separator; a value
                # containing it would produce an unparseable expressions file.
                case "$value" in
                    *'==>'*)
                        log_error "A value under $key contains the '==>' separator and cannot be expressed."
                        log_error "Handle it by hand; fingerprint $(fingerprint "$value")"
                        exit 1 ;;
                esac

                if is_allowlisted "$key" "$value"; then
                    log_info "Allowlisted (gitleaks): $key / $(fingerprint "$value")"
                    continue
                fi

                printf '%s\t%s\n' "$value" "$key" >> "$pairs_file"
            done < <(printf '%s\n' "$blob" | extract_assignments)
        done < <(git -C "$mirror" rev-list --all -- "$path" 2>/dev/null || true)
    done

    # Aggregate to one line per distinct value: VALUE<TAB>KEY[ KEY...]
    local agg_file="$out_dir/.agg.$$"
    : > "$agg_file"
    chmod 600 "$agg_file"
    awk -F'\t' '
        {
            v = $1; k = $2
            if (!(v in seen)) { seen[v] = 1; order[++n] = v; keys[v] = k; next }
            if (index(" " keys[v] " ", " " k " ") == 0) keys[v] = keys[v] " " k
        }
        END { for (i = 1; i <= n; i++) printf "%s\t%s\n", order[i], keys[order[i]] }
    ' "$pairs_file" > "$agg_file"

    local distinct
    distinct="$(wc -l < "$agg_file" | tr -d '[:space:]')"

    if [[ "$distinct" -eq 0 ]]; then
        rm -f "$agg_file"
        log_error "No in-scope literals found across ${#SCOPE_PATHS[@]} path(s) and $scanned_blobs blob(s)."
        log_error "That is almost certainly wrong for this repository -- check the mirror is complete"
        log_error "(git clone --mirror, not a shallow or single-branch clone)."
        exit 1
    fi

    # Snapshot the mirror's HEAD tree once. A value that still exists at HEAD is
    # not a historical credential: HEAD is clean (#462 re-scoping), so anything
    # surviving there is a dev default -- a compose service name, a database
    # name, the literal 'password'. Rewriting those would corrupt unrelated
    # history for no security gain.
    local head_content="$out_dir/.head.$$"
    : > "$head_content"
    chmod 600 "$head_content"
    git -C "$mirror" ls-tree -r HEAD 2>/dev/null \
        | awk '$2 == "blob" { print $3 }' \
        | git -C "$mirror" cat-file --batch --buffer 2>/dev/null \
        > "$head_content" || true
    if [[ ! -s "$head_content" ]]; then
        log_warn "Could not read the mirror's HEAD tree; the present-at-head exclusion is disabled."
    fi

    # Write the expressions file with restrictive permissions BEFORE any
    # content reaches it.
    : > "$out_file"
    chmod 600 "$out_file"
    {
        echo "# git filter-repo --replace-text expressions for cardtechie/cardalmanac-app#462"
        echo "# Generated $(date -u '+%Y-%m-%dT%H:%M:%SZ') by build/$(basename "$0")"
        echo "# CONTAINS LIVE CREDENTIALS -- do not commit, paste, or upload."
    } >> "$out_file"

    echo ""
    echo "Distinct in-scope literals found: $distinct  (from $scanned_blobs historical blob(s))"
    echo ""

    local skipped_file="$out_dir/.skipped.$$"
    : > "$skipped_file"
    chmod 600 "$skipped_file"

    echo "INCLUDED -- written to the expressions file"
    printf '%-14s  %-6s  %s\n' "FINGERPRINT" "CHARS" "SEEN AS"
    printf '%-14s  %-6s  %s\n' "--------------" "------" "-------"

    local seen_keys reason included=0 skipped=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        value="${line%%$'\t'*}"
        seen_keys="${line#*$'\t'}"

        reason=""
        if [[ ${#value} -lt "$min_length" ]]; then
            reason="too-short"
        elif [[ -s "$head_content" ]] && LC_ALL=C grep -F -a -q -e "$value" "$head_content"; then
            reason="present-at-head"
        fi

        if [[ -n "$reason" ]]; then
            skipped=$((skipped + 1))
            printf '%-14s  %-6s  %-16s  %s\n' \
                "$(fingerprint "$value")" "${#value}" "$reason" "$seen_keys" >> "$skipped_file"
            continue
        fi

        printf 'literal:%s==>***REMOVED***\n' "$value" >> "$out_file"
        included=$((included + 1))
        printf '%-14s  %-6s  %s\n' "$(fingerprint "$value")" "${#value}" "$seen_keys"
    done < "$agg_file"
    rm -f "$pairs_file" "$agg_file" "$head_content"
    echo ""

    if [[ "$skipped" -gt 0 ]]; then
        echo "EXCLUDED -- reported, not written (see --help for what each reason means)"
        printf '%-14s  %-6s  %-16s  %s\n' "FINGERPRINT" "CHARS" "REASON" "SEEN AS"
        printf '%-14s  %-6s  %-16s  %s\n' "--------------" "------" "----------------" "-------"
        cat "$skipped_file"
        echo ""
    fi
    rm -f "$skipped_file"

    if [[ "$included" -eq 0 ]]; then
        log_error "Every candidate was excluded -- the expressions file has no literals."
        log_error "filter-repo would be a no-op. Review the EXCLUDED table above and lower"
        log_error "--min-length, or add the intended values by hand."
        exit 1
    fi

    log_success "Wrote $out_file (mode 0600) -- $included literal(s), $skipped excluded"
    echo ""
    echo "Next:"
    echo "  1. Review both tables above and the expressions file line count."
    echo "  2. git -C <mirror> filter-repo --replace-text \"$out_file\""
    echo "  3. build/verify-secret-purge.sh <pre-rewrite-mirror> <rewritten-mirror>"
    echo ""
    log_warn "Delete $out_file once the purge is verified."
}

main "$@"
