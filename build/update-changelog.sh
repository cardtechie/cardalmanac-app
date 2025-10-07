#!/bin/bash

# update-changelog.sh - Automated changelog management for Card Almanac
# Based on Keep a Changelog format (https://keepachangelog.com)
# Integrates with semantic versioning and GitHub for automated changelog updates

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
VERSION_SCRIPT="$SCRIPT_DIR/version.sh"

# GitHub repository info (extracted from git remote)
GITHUB_REPO=""
GITHUB_OWNER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [options] [action] [version]

Actions:
    init            Initialize a new CHANGELOG.md file
    preview         Preview changes that would be made
    update          Update changelog with new version
    add-unreleased  Add entry to Unreleased section
    finalize        Move Unreleased entries to version section

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    --dry-run       Show what would be done without making changes
    --force         Force overwrite existing entries
    --github-token  GitHub token for API access

Examples:
    $0 init                          # Create new CHANGELOG.md
    $0 preview                       # Preview next version update
    $0 update                        # Update with current version
    $0 update 1.2.3                  # Update with specific version
    $0 add-unreleased "Added new feature"
    $0 finalize                      # Move unreleased to version

Entry Types:
    Added       New features
    Changed     Changes in existing functionality  
    Deprecated  Soon-to-be removed features
    Removed     Removed features
    Fixed       Bug fixes
    Security    Security fixes
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
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# GitHub utilities
detect_github_repo() {
    if [[ -n "$GITHUB_REPO" && -n "$GITHUB_OWNER" ]]; then
        return
    fi
    
    local remote_url
    if remote_url=$(git remote get-url origin 2>/dev/null); then
        # Parse GitHub URL
        if [[ $remote_url =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
            GITHUB_OWNER="${BASH_REMATCH[1]}"
            GITHUB_REPO="${BASH_REMATCH[2]}"
            log_info "Detected GitHub repo: $GITHUB_OWNER/$GITHUB_REPO"
        else
            log_warn "Could not parse GitHub repo from remote URL: $remote_url"
        fi
    else
        log_warn "No git remote origin found"
    fi
}

get_github_compare_url() {
    local from_tag="$1"
    local to_tag="$2"
    
    if [[ -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
        echo "https://github.com/$GITHUB_OWNER/$GITHUB_REPO/compare/$from_tag...$to_tag"
    else
        echo ""
    fi
}

get_commits_since_tag() {
    local since_tag="$1"
    local format="${2:-oneline}"
    local max_commits=15  # Limit commits for readability
    
    if [[ -z "$since_tag" ]]; then
        # Get recent commits if no tag
        git log --pretty="format:$format" -n $max_commits
    else
        # Get commits since tag, but limit to reasonable number
        git log --pretty="format:$format" -n $max_commits "${since_tag}..HEAD"
    fi
}

categorize_commit() {
    local commit_msg="$1"
    local type=""
    
    # Convert to lowercase for matching
    local msg_lower=$(echo "$commit_msg" | tr '[:upper:]' '[:lower:]')
    
    # Detect conventional commit types
    if [[ $msg_lower =~ ^feat(\(.+\))?:.*$ ]]; then
        type="Added"
    elif [[ $msg_lower =~ ^fix(\(.+\))?:.*$ ]]; then
        type="Fixed"
    elif [[ $msg_lower =~ ^docs(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^style(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^refactor(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^test(\(.+\))?:.*$ ]]; then
        type="Added"
    elif [[ $msg_lower =~ ^chore(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^perf(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^build(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^ci(\(.+\))?:.*$ ]]; then
        type="Changed"
    elif [[ $msg_lower =~ ^security(\(.+\))?:.*$ ]]; then
        type="Security"
    # Keyword-based detection
    elif [[ $msg_lower =~ (add|new|feat|feature|implement) ]]; then
        type="Added"
    elif [[ $msg_lower =~ (fix|bug|patch|resolve) ]]; then
        type="Fixed"
    elif [[ $msg_lower =~ (update|change|modify|improve|enhance) ]]; then
        type="Changed"
    elif [[ $msg_lower =~ (remove|delete|drop) ]]; then
        type="Removed"
    elif [[ $msg_lower =~ (deprecate) ]]; then
        type="Deprecated"
    elif [[ $msg_lower =~ (security|cve|vulnerability) ]]; then
        type="Security"
    else
        type="Changed"  # Default category
    fi
    
    echo "$type"
}

# Changelog utilities
create_changelog_header() {
    cat << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

EOF
}

get_latest_version_from_changelog() {
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        echo ""
        return
    fi
    
    # Extract first version section
    grep -E "^## \[[0-9]+\.[0-9]+\.[0-9]+\]" "$CHANGELOG_FILE" | head -n1 | sed -E 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/' || echo ""
}

has_unreleased_section() {
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        return 1
    fi
    
    grep -q "^## \[Unreleased\]" "$CHANGELOG_FILE"
}

get_unreleased_content() {
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        echo ""
        return
    fi
    
    # Extract content between [Unreleased] and next version section
    awk '/^## \[Unreleased\]/{flag=1; next} /^## \[/{flag=0} flag' "$CHANGELOG_FILE"
}

generate_version_entry() {
    local version="$1"
    local date="${2:-$(date +%Y-%m-%d)}"
    local previous_version="$3"
    
    echo "## [$version] - $date"
    echo ""
    
    # Add compare URL if we have GitHub info and previous version
    if [[ -n "$previous_version" && -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
        echo "### 🔗 Links"
        echo "- [View Changes]($(get_github_compare_url "v$previous_version" "v$version"))"
        echo ""
    fi
    
    # Get commits since last version
    local since_tag=""
    if [[ -n "$previous_version" ]]; then
        since_tag="v$previous_version"
    fi
    
    # Categorize commits (using temporary files for compatibility)
    local temp_dir=$(mktemp -d)
    local added_file="$temp_dir/added"
    local changed_file="$temp_dir/changed"  
    local deprecated_file="$temp_dir/deprecated"
    local removed_file="$temp_dir/removed"
    local fixed_file="$temp_dir/fixed"
    local security_file="$temp_dir/security"
    
    touch "$added_file" "$changed_file" "$deprecated_file" "$removed_file" "$fixed_file" "$security_file"
    
    # Process commits
    while IFS= read -r commit; do
        if [[ -n "$commit" ]]; then
            # Skip merge commits, formatting fixes, and dependency bumps
            if [[ $commit =~ ^Merge\ (pull\ request|branch) ]] || \
               [[ $commit =~ ^Merge\ remote-tracking\ branch ]] || \
               [[ $commit =~ ^\#[0-9]+:\ (Fix|Update)\ (final\ )?[Pp]rettier\ formatting ]] || \
               [[ $commit =~ ^Bump\ .*\ from\ .*\ to\ .* ]] || \
               [[ ${#commit} -gt 100 ]]; then
                continue
            fi
            
            local category=$(categorize_commit "$commit")
            case "$category" in
                "Added")
                    echo "- $commit" >> "$added_file"
                    ;;
                "Changed")
                    echo "- $commit" >> "$changed_file"
                    ;;
                "Deprecated")
                    echo "- $commit" >> "$deprecated_file"
                    ;;
                "Removed")
                    echo "- $commit" >> "$removed_file"
                    ;;
                "Fixed")
                    echo "- $commit" >> "$fixed_file"
                    ;;
                "Security")
                    echo "- $commit" >> "$security_file"
                    ;;
            esac
        fi
    done < <(get_commits_since_tag "$since_tag" "%s")
    
    # Output categorized changes
    for category in "Added" "Changed" "Deprecated" "Removed" "Fixed" "Security"; do
        local category_file=""
        case "$category" in
            "Added") category_file="$added_file" ;;
            "Changed") category_file="$changed_file" ;;
            "Deprecated") category_file="$deprecated_file" ;;
            "Removed") category_file="$removed_file" ;;
            "Fixed") category_file="$fixed_file" ;;
            "Security") category_file="$security_file" ;;
        esac
        
        if [[ -s "$category_file" ]]; then
            echo "### $category"
            # Limit to first 10 entries per category for readability
            head -n 10 "$category_file"
            local total_lines=$(wc -l < "$category_file")
            if [[ $total_lines -gt 10 ]]; then
                echo "- ... and $((total_lines - 10)) more"
            fi
            echo ""
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Actions
action_init() {
    if [[ -f "$CHANGELOG_FILE" && "${FORCE:-false}" != "true" ]]; then
        log_error "CHANGELOG.md already exists. Use --force to overwrite."
        exit 1
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would create CHANGELOG.md with initial content"
        return
    fi
    
    create_changelog_header > "$CHANGELOG_FILE"
    log_success "Created $CHANGELOG_FILE"
}

action_preview() {
    local version="${1:-$($VERSION_SCRIPT current)}"
    local previous_version=$(get_latest_version_from_changelog)
    
    echo "Preview of changelog entry for version $version:"
    echo "================================================="
    echo ""
    generate_version_entry "$version" "$(date +%Y-%m-%d)" "$previous_version"
}

action_update() {
    local version="${1:-$($VERSION_SCRIPT current)}"
    local previous_version=$(get_latest_version_from_changelog)
    
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_error "CHANGELOG.md not found. Run 'init' first."
        exit 1
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would update CHANGELOG.md with version $version"
        action_preview "$version"
        return
    fi
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Generate new entry
    local new_entry=$(generate_version_entry "$version" "$(date +%Y-%m-%d)" "$previous_version")
    
    # Update changelog
    if has_unreleased_section; then
        # Replace Unreleased section with version section
        awk -v version="$version" -v entry="$new_entry" '
        /^## \[Unreleased\]/ {
            print "## [Unreleased]"
            print ""
            print entry
            next
        }
        { print }' "$CHANGELOG_FILE" > "$temp_file"
    else
        # Insert after header
        awk -v version="$version" -v entry="$new_entry" '
        NR <= 6 { print; next }
        !inserted && /^## / {
            print entry
            print ""
            inserted = 1
        }
        { print }' "$CHANGELOG_FILE" > "$temp_file"
    fi
    
    mv "$temp_file" "$CHANGELOG_FILE"
    
    # Add compare links section at the end if GitHub repo detected
    if [[ -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
        add_compare_links "$version"
    fi
    
    log_success "Updated CHANGELOG.md with version $version"
}

action_add_unreleased() {
    local entry="$1"
    local type="${2:-Changed}"
    
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_error "CHANGELOG.md not found. Run 'init' first."
        exit 1
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would add to Unreleased section: $entry"
        return
    fi
    
    # Find or create the type section under Unreleased
    local temp_file=$(mktemp)
    
    awk -v entry="$entry" -v type="$type" '
    /^## \[Unreleased\]/ {
        in_unreleased = 1
        print
        next
    }
    in_unreleased && /^## \[/ && !/^## \[Unreleased\]/ {
        # End of unreleased section
        if (!added_entry) {
            print ""
            print "### " type
            print "- " entry
            print ""
        }
        in_unreleased = 0
        print
        next
    }
    in_unreleased && /^### '"$type"'/ {
        in_type_section = 1
        print
        next
    }
    in_unreleased && in_type_section && (/^### / || /^## \[/) {
        # End of type section
        print "- " entry
        in_type_section = 0
        added_entry = 1
        print
        next
    }
    { print }
    END {
        if (in_unreleased && !added_entry) {
            print ""
            print "### " type  
            print "- " entry
        }
    }' "$CHANGELOG_FILE" > "$temp_file"
    
    mv "$temp_file" "$CHANGELOG_FILE"
    log_success "Added entry to Unreleased section"
}

action_finalize() {
    local version="${1:-$($VERSION_SCRIPT current)}"
    
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_error "CHANGELOG.md not found. Run 'init' first."
        exit 1
    fi
    
    if ! has_unreleased_section; then
        log_warn "No Unreleased section found"
        return
    fi
    
    local unreleased_content=$(get_unreleased_content)
    if [[ -z "$(echo "$unreleased_content" | sed '/^[[:space:]]*$/d')" ]]; then
        log_warn "No unreleased changes to finalize"
        return
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would finalize unreleased changes to version $version"
        return
    fi
    
    # Replace unreleased with version section
    local temp_file=$(mktemp)
    local date=$(date +%Y-%m-%d)
    
    awk -v version="$version" -v date="$date" '
    /^## \[Unreleased\]/ {
        print "## [Unreleased]"
        print ""
        print "## [" version "] - " date
        next
    }
    { print }' "$CHANGELOG_FILE" > "$temp_file"
    
    mv "$temp_file" "$CHANGELOG_FILE"
    log_success "Finalized unreleased changes to version $version"
}

add_compare_links() {
    local version="$1"
    
    # Add compare links at the end of the file
    if ! grep -q "^\[Unreleased\]:" "$CHANGELOG_FILE"; then
        echo "" >> "$CHANGELOG_FILE"
        echo "[Unreleased]: https://github.com/$GITHUB_OWNER/$GITHUB_REPO/compare/v$version...HEAD" >> "$CHANGELOG_FILE"
        echo "[${version}]: https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/tag/v$version" >> "$CHANGELOG_FILE"
    fi
}

# Main script
main() {
    local action="preview"
    local version=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --github-token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            init|preview|update|add-unreleased|finalize)
                action="$1"
                shift
                ;;
            [0-9]*.[0-9]*.[0-9]*)
                version="$1"
                shift
                ;;
            *)
                if [[ "$action" == "add-unreleased" && -z "${ENTRY:-}" ]]; then
                    ENTRY="$1"
                    shift
                else
                    log_error "Unknown argument: $1"
                    usage
                    exit 1
                fi
                ;;
        esac
    done
    
    # Ensure we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Detect GitHub repository
    detect_github_repo
    
    # Execute action
    case "$action" in
        init)
            action_init
            ;;
        preview)
            action_preview "$version"
            ;;
        update)
            action_update "$version"
            ;;
        add-unreleased)
            if [[ -z "${ENTRY:-}" ]]; then
                log_error "Entry text required for add-unreleased action"
                exit 1
            fi
            action_add_unreleased "$ENTRY"
            ;;
        finalize)
            action_finalize "$version"
            ;;
        *)
            log_error "Unknown action: $action"
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi