#!/bin/bash

# version.sh - Semantic versioning script for Card Almanac
# Based on the tradingcardapi-api project's version management system
# Supports branch-aware versioning with semantic versioning (semver)

set -euo pipefail

# Configuration
DEFAULT_VERSION="0.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [options] [action]

Actions:
    current         Show current version (default)
    next            Calculate next appropriate version for current branch
    next-major      Calculate next major version
    next-minor      Calculate next minor version  
    next-patch      Calculate next patch version
    set-env         Set CI environment variables

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    --branch BRANCH Override current branch detection
    --format FORMAT Output format (version|tag|env) [default: version]

Examples:
    $0                  # Show current version
    $0 current          # Show current version
    $0 next             # Show next appropriate version for branch
    $0 next-patch       # Show next patch version
    $0 set-env          # Set environment variables for CI
    $0 --format tag     # Show as git tag (v1.2.3)
    $0 --format env     # Show as env vars (VERSION=1.2.3)

Branch Types:
    master      -> Final releases (1.2.3)
    develop     -> Beta releases (1.2.3-beta.N)
    release/*   -> Release candidates (1.2.3-rc.N)  
    hotfix/*    -> Hotfix releases (1.2.4)
    feature/*   -> Feature versions (1.2.3-feature.branch-name)
    other       -> Development versions (1.2.3-dev.sha)
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

# Git utilities
get_current_branch() {
    if [[ -n "${OVERRIDE_BRANCH:-}" ]]; then
        echo "$OVERRIDE_BRANCH"
        return
    fi
    
    # Try multiple methods to get branch name
    local branch=""
    
    # Method 1: git symbolic-ref (works in normal repos)
    if branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
        echo "$branch"
        return
    fi
    
    # Method 2: CI environment variables
    if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        echo "$GITHUB_REF_NAME"
        return
    fi
    
    if [[ -n "${CI_COMMIT_REF_NAME:-}" ]]; then
        echo "$CI_COMMIT_REF_NAME"
        return
    fi
    
    # Method 3: git describe (for detached HEAD)
    if branch=$(git describe --all --exact-match HEAD 2>/dev/null); then
        echo "${branch#*/}"
        return
    fi
    
    # Default fallback
    echo "unknown"
}

get_latest_tag() {
    local pattern="${1:-v*}"
    git tag -l "$pattern" | sort -V | tail -n1 || echo ""
}

get_latest_version_tag() {
    # Get the latest semantic version tag (v*.*.*)
    git tag -l "v*.*.*" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || echo ""
}

get_commit_count_since_tag() {
    local tag="$1"
    if [[ -z "$tag" ]]; then
        # Count all commits if no tag
        git rev-list --count HEAD
    else
        git rev-list --count "${tag}..HEAD"
    fi
}

get_short_sha() {
    git rev-parse --short HEAD
}

# Version parsing and manipulation
parse_version() {
    local version="$1"
    # Remove 'v' prefix if present
    version="${version#v}"
    
    # Extract major.minor.patch
    if [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
    else
        echo "0 1 0"  # Default fallback
    fi
}

increment_version() {
    local current="$1"
    local type="$2"
    
    read -r major minor patch <<< "$(parse_version "$current")"
    
    case "$type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "${major}.$((minor + 1)).0"
            ;;
        patch)
            echo "${major}.${minor}.$((patch + 1))"
            ;;
        *)
            echo "$current"
            ;;
    esac
}

# Determine next version type based on branch
determine_version_increment() {
    local branch="$1"
    
    case "$branch" in
        master|main)
            # On main: should be a tagged release, no increment needed
            echo "none"
            ;;
        develop)
            # Develop branch: next minor version for beta releases
            echo "minor"
            ;;
        release/*)
            # Release branch: extract version from branch name
            echo "release"
            ;;
        hotfix/*)
            # Hotfix: increment patch version
            echo "patch"
            ;;
        feature/*)
            # Feature: typically minor increment for preview
            echo "minor"
            ;;
        *)
            # Other branches: patch increment
            echo "patch"
            ;;
    esac
}

# Get the appropriate base version for calculations
get_base_version_for_branch() {
    local branch="$1"
    local latest_tag=$(get_latest_version_tag)
    
    if [[ -n "$latest_tag" ]]; then
        # Remove 'v' prefix from tag
        echo "${latest_tag#v}"
    else
        # No tags yet, use default
        echo "$DEFAULT_VERSION"
    fi
}

# Branch-specific version calculation
calculate_version_for_branch() {
    local branch="$1"
    local base_version="$2"
    
    case "$branch" in
        master|main)
            # Main branch: use latest tag or increment if ahead
            local latest_tag=$(get_latest_version_tag)
            local commit_count=0
            
            if [[ -n "$latest_tag" ]]; then
                commit_count=$(get_commit_count_since_tag "$latest_tag")
                if [[ $commit_count -eq 0 ]]; then
                    # On exact tag
                    echo "${latest_tag#v}"
                else
                    # Ahead of tag on main - this shouldn't happen in normal workflow
                    # but if it does, increment patch
                    local next_patch=$(increment_version "${latest_tag#v}" "patch")
                    echo "$next_patch"
                fi
            else
                # No tags yet, start with default
                echo "$DEFAULT_VERSION"
            fi
            ;;
            
        develop)
            # Develop branch: next minor version as beta
            local latest_tag=$(get_latest_version_tag)
            local commit_count=0
            
            if [[ -n "$latest_tag" ]]; then
                commit_count=$(get_commit_count_since_tag "$latest_tag")
                if [[ $commit_count -eq 0 ]]; then
                    # On exact tag, increment minor for next beta
                    local next_minor=$(increment_version "${latest_tag#v}" "minor")
                    echo "${next_minor}-beta.1"
                else
                    # Ahead of tag, use incremented minor with commit count
                    local next_minor=$(increment_version "${latest_tag#v}" "minor")
                    echo "${next_minor}-beta.${commit_count}"
                fi
            else
                # No tags yet
                echo "${DEFAULT_VERSION}-beta.1"
            fi
            ;;
            
        release/*)
            # Release branch: extract version from branch name or increment
            local version_from_branch="${branch#release/}"
            local commit_count=$(get_commit_count_since_tag "$(get_latest_version_tag)")
            
            # Check if branch name contains a version
            if [[ $version_from_branch =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                # Branch has explicit version
                if [[ $commit_count -eq 0 ]]; then
                    echo "$version_from_branch"
                else
                    echo "${version_from_branch}-rc.${commit_count}"
                fi
            else
                # Branch doesn't have version, calculate next minor
                local next_minor=$(increment_version "$base_version" "minor")
                if [[ $commit_count -eq 0 ]]; then
                    echo "${next_minor}-rc.1"
                else
                    echo "${next_minor}-rc.${commit_count}"
                fi
            fi
            ;;
            
        hotfix/*)
            # Hotfix: increment patch version
            local latest_tag=$(get_latest_version_tag)
            local commit_count=0
            
            if [[ -n "$latest_tag" ]]; then
                commit_count=$(get_commit_count_since_tag "$latest_tag")
                local next_patch=$(increment_version "${latest_tag#v}" "patch")
                
                if [[ $commit_count -eq 0 ]]; then
                    echo "$next_patch"
                else
                    echo "${next_patch}-hotfix.${commit_count}"
                fi
            else
                # No tags yet, use default with patch increment
                local next_patch=$(increment_version "$DEFAULT_VERSION" "patch")
                echo "$next_patch"
            fi
            ;;
            
        feature/*)
            # Feature: next minor version with feature identifier
            local feature_name="${branch#feature/}"
            # Sanitize branch name for version
            feature_name=$(echo "$feature_name" | sed 's/[^a-zA-Z0-9.-]/-/g' | sed 's/--*/-/g')
            
            local latest_tag=$(get_latest_version_tag)
            local commit_count=0
            
            if [[ -n "$latest_tag" ]]; then
                commit_count=$(get_commit_count_since_tag "$latest_tag")
                local next_minor=$(increment_version "${latest_tag#v}" "minor")
                echo "${next_minor}-feature.${feature_name}.${commit_count}"
            else
                # No tags yet
                local next_minor=$(increment_version "$DEFAULT_VERSION" "minor")
                echo "${next_minor}-feature.${feature_name}.1"
            fi
            ;;
            
        *)
            # Other branches: patch increment with dev identifier
            local sha=$(get_short_sha)
            local next_patch=$(increment_version "$base_version" "patch")
            echo "${next_patch}-dev.${sha}"
            ;;
    esac
}

# Main version calculation
get_current_version() {
    cd "$PROJECT_ROOT"
    
    local branch=$(get_current_branch)
    log_info "Current branch: $branch"
    
    # Get base version from latest tag
    local latest_tag=$(get_latest_version_tag)
    local base_version=""
    
    if [[ -n "$latest_tag" ]]; then
        base_version="${latest_tag#v}"
        log_info "Latest version tag: $latest_tag"
    else
        base_version="$DEFAULT_VERSION"
        log_info "No version tags found, using default: $base_version"
    fi
    
    # Calculate version based on branch
    local version=$(calculate_version_for_branch "$branch" "$base_version")
    
    log_info "Calculated version: $version"
    echo "$version"
}

# Output formatting
format_output() {
    local version="$1"
    local format="${OUTPUT_FORMAT:-version}"
    
    case "$format" in
        version)
            echo "$version"
            ;;
        tag)
            echo "v$version"
            ;;
        env)
            echo "VERSION=$version"
            echo "VERSION_TAG=v$version"
            echo "VERSION_MAJOR=$(parse_version "$version" | cut -d' ' -f1)"
            echo "VERSION_MINOR=$(parse_version "$version" | cut -d' ' -f2)"
            echo "VERSION_PATCH=$(parse_version "$version" | cut -d' ' -f3)"
            ;;
        *)
            log_error "Unknown format: $format"
            exit 1
            ;;
    esac
}

# Actions
action_current() {
    local version=$(get_current_version)
    format_output "$version"
}

action_next() {
    local type="$1"
    local current=$(get_current_version)
    # Strip any pre-release suffix for next version calculation
    local base_version=$(echo "$current" | sed 's/-.*$//')
    local next_version=$(increment_version "$base_version" "$type")
    format_output "$next_version"
}

action_next_for_branch() {
    local branch=$(get_current_branch)
    local increment_type=$(determine_version_increment "$branch")
    local base_version=$(get_base_version_for_branch "$branch")
    
    log_info "Branch: $branch"
    log_info "Increment type: $increment_type"
    log_info "Base version: $base_version"
    
    case "$increment_type" in
        "none")
            # On main branch, show current version
            format_output "$(get_current_version)"
            ;;
        "release")
            # Release branch logic handled in calculate_version_for_branch
            format_output "$(calculate_version_for_branch "$branch" "$base_version")"
            ;;
        *)
            # Calculate next version based on increment type
            local next_version=$(increment_version "$base_version" "$increment_type")
            format_output "$next_version"
            ;;
    esac
}

action_set_env() {
    local version=$(get_current_version)
    
    # Set environment variables for CI
    echo "VERSION=$version"
    echo "VERSION_TAG=v$version"
    
    # Parse version components
    read -r major minor patch <<< "$(parse_version "$version")"
    echo "VERSION_MAJOR=$major"
    echo "VERSION_MINOR=$minor"
    echo "VERSION_PATCH=$patch"
    
    # Set in GitHub Actions if available
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        {
            echo "VERSION=$version"
            echo "VERSION_TAG=v$version"
            echo "VERSION_MAJOR=$major"
            echo "VERSION_MINOR=$minor"
            echo "VERSION_PATCH=$patch"
        } >> "$GITHUB_ENV"
        log_success "Environment variables set for GitHub Actions"
    fi
}

# Main script
main() {
    local action="current"
    
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
            --branch)
                OVERRIDE_BRANCH="$2"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            current|next|next-major|next-minor|next-patch|set-env)
                action="$1"
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Ensure we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Execute action
    case "$action" in
        current)
            action_current
            ;;
        next)
            action_next_for_branch
            ;;
        next-major)
            action_next "major"
            ;;
        next-minor)
            action_next "minor"
            ;;
        next-patch)
            action_next "patch"
            ;;
        set-env)
            action_set_env
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi