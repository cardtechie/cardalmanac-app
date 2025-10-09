#!/bin/bash

# generate-release-notes.sh - AI-powered release notes generation for Card Almanac
# Integrates with Claude API for intelligent release summaries and GitHub for metadata

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_SCRIPT="$SCRIPT_DIR/version.sh"

# GitHub repository info
GITHUB_REPO=""
GITHUB_OWNER=""

# API Configuration
CLAUDE_API_URL="https://api.anthropic.com/v1/messages"
CLAUDE_MODEL="claude-3-haiku-20240307"
CLAUDE_MAX_TOKENS=2000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [options] [version]

Generate AI-powered release notes for Card Almanac releases.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --dry-run          Show what would be generated without API calls
    --no-ai            Skip AI generation, use template only
    --format FORMAT     Output format (markdown|github|text) [default: markdown]
    --since VERSION     Compare since specific version
    --claude-api-key    Claude API key (or set CLAUDE_API_KEY env var)

Examples:
    $0                              # Generate for current version
    $0 1.2.3                        # Generate for specific version
    $0 --since 1.1.0               # Compare since specific version
    $0 --format github             # GitHub release format
    $0 --no-ai                     # Template only (no AI)

Environment Variables:
    CLAUDE_API_KEY      Claude API key for AI-powered summaries
    GITHUB_TOKEN        GitHub API token for enhanced metadata

Output Formats:
    markdown    Standard markdown format
    github      GitHub release format
    text        Plain text format
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
        if [[ $remote_url =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
            GITHUB_OWNER="${BASH_REMATCH[1]}"
            GITHUB_REPO="${BASH_REMATCH[2]}"
            log_info "Detected GitHub repo: $GITHUB_OWNER/$GITHUB_REPO"
        fi
    fi
}

get_commits_since_tag() {
    local since_tag="$1"
    local format="${2:-%H|%s|%an|%ad}"
    local max_commits=12  # Limit to recent commits
    
    if [[ -z "$since_tag" ]]; then
        # No tag provided, get recent commits only
        git log --pretty="format:$format" --date=short -n $max_commits
    else
        # Get commits since tag, but limit to reasonable number
        git log --pretty="format:$format" --date=short -n $max_commits "${since_tag}..HEAD"
    fi
}

get_github_compare_url() {
    local from_tag="$1"
    local to_tag="$2"
    
    if [[ -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
        echo "https://github.com/$GITHUB_OWNER/$GITHUB_REPO/compare/$from_tag...$to_tag"
    fi
}

get_docker_image_info() {
    local version="$1"
    
    # Card Almanac Docker image info
    cat << EOF
**Docker Images:**
- \`picklewagon/cardalmanac-app:${version}\`
- \`picklewagon/cardalmanac-app:latest\`

**Pull Commands:**
\`\`\`bash
docker pull picklewagon/cardalmanac-app:${version}
docker pull picklewagon/cardalmanac-app:latest
\`\`\`
EOF
}

# Claude API utilities
call_claude_api() {
    local prompt="$1"
    local max_tokens="${2:-$CLAUDE_MAX_TOKENS}"
    
    if [[ -z "${CLAUDE_API_KEY:-}" ]]; then
        log_warn "No Claude API key provided. Set CLAUDE_API_KEY environment variable."
        return 1
    fi
    
    local payload=$(cat << EOF | jq -c
{
    "model": "$CLAUDE_MODEL",
    "max_tokens": $max_tokens,
    "messages": [
        {
            "role": "user",
            "content": "$prompt"
        }
    ]
}
EOF
)
    
    local response
    if response=$(curl -s -X POST "$CLAUDE_API_URL" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload" \
        --max-time 30); then
        
        # Extract content from response
        echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null || {
            log_error "Failed to parse Claude API response"
            return 1
        }
    else
        log_error "Failed to call Claude API"
        return 1
    fi
}

generate_ai_summary() {
    local version="$1"
    local commits="$2"
    local previous_version="$3"
    
    local prompt=$(cat << EOF
You are helping generate release notes for the Card Almanac project, a Laravel-based web application for trading card collectors. 

Please create a concise, engaging release summary based on these git commits:

$commits

Guidelines:
- Write 1-2 paragraphs (3-5 sentences total)
- Focus on user-facing improvements and new features
- Use professional but approachable tone
- Mention specific functionality when relevant
- Avoid technical jargon
- Format as markdown

Version: $version
$(if [[ -n "$previous_version" ]]; then echo "Previous version: $previous_version"; fi)

Generate only the release summary content, no headers or additional formatting.
EOF
)
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "*AI-generated summary would appear here*"
        return
    fi
    
    call_claude_api "$prompt"
}

# Release notes generation
generate_commit_list() {
    local since_tag="$1"
    local format="${2:-markdown}"
    
    local commits=""
    while IFS='|' read -r hash subject author date; do
        if [[ -n "$hash" ]]; then
            case "$format" in
                markdown)
                    commits+="- $subject ($hash)\n"
                    ;;
                github)
                    commits+="* $subject (@$author)\n"
                    ;;
                text)
                    commits+="* $subject\n"
                    ;;
            esac
        fi
    done < <(get_commits_since_tag "$since_tag")
    
    echo -e "$commits"
}

categorize_changes() {
    local since_tag="$1"
    
    # Use temporary files instead of associative arrays for compatibility
    local temp_dir=$(mktemp -d)
    local features_file="$temp_dir/features"
    local improvements_file="$temp_dir/improvements"
    local bugfixes_file="$temp_dir/bugfixes"
    local security_file="$temp_dir/security"
    local dependencies_file="$temp_dir/dependencies"
    local other_file="$temp_dir/other"
    
    touch "$features_file" "$improvements_file" "$bugfixes_file" "$security_file" "$dependencies_file" "$other_file"
    
    while IFS='|' read -r hash subject author date; do
        if [[ -n "$hash" ]]; then
            # Skip merge commits and other noise
            if [[ $subject =~ ^Merge\ (pull\ request|branch) ]] || \
               [[ $subject =~ ^Merge\ remote-tracking\ branch ]] || \
               [[ $subject =~ ^\#[0-9]+:\ (Fix|Update)\ (final\ )?[Pp]rettier\ formatting ]] || \
               [[ $subject =~ ^Bump\ .*\ from\ .*\ to\ .* ]] || \
               [[ ${#subject} -gt 100 ]]; then
                continue
            fi
            
            local subject_lower=$(echo "$subject" | tr '[:upper:]' '[:lower:]')
            
            if [[ $subject_lower =~ (feat|feature|add|new|implement) ]]; then
                echo "- $subject" >> "$features_file"
            elif [[ $subject_lower =~ (fix|bug|patch|resolve) ]]; then
                echo "- $subject" >> "$bugfixes_file"
            elif [[ $subject_lower =~ (improve|enhance|update|optimize|refactor) ]]; then
                echo "- $subject" >> "$improvements_file"
            elif [[ $subject_lower =~ (security|cve|vulnerability) ]]; then
                echo "- $subject" >> "$security_file"
            elif [[ $subject_lower =~ (dep|dependency|bump|upgrade|package) ]]; then
                echo "- $subject" >> "$dependencies_file"
            else
                echo "- $subject" >> "$other_file"
            fi
        fi
    done < <(get_commits_since_tag "$since_tag")
    
    # Output non-empty categories (limited for readability)
    local categories="Features Improvements Bug_Fixes Security Dependencies Other"
    
    for category_name in $categories; do
        local category_file=""
        local display_name=""
        
        case "$category_name" in
            "Features") 
                category_file="$features_file"
                display_name="Features"
                ;;
            "Improvements")
                category_file="$improvements_file" 
                display_name="Improvements"
                ;;
            "Bug_Fixes")
                category_file="$bugfixes_file"
                display_name="Bug Fixes"
                ;;
            "Security")
                category_file="$security_file"
                display_name="Security"
                ;;
            "Dependencies")
                category_file="$dependencies_file"
                display_name="Dependencies"
                ;;
            "Other")
                category_file="$other_file"
                display_name="Other"
                ;;
        esac
        
        if [[ -s "$category_file" ]]; then
            echo "### $display_name"
            # Limit to first 8 entries per category for readability
            head -n 8 "$category_file"
            local total_lines=$(wc -l < "$category_file")
            if [[ $total_lines -gt 8 ]]; then
                echo "- ... and $((total_lines - 8)) more changes"
            fi
            echo ""
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
}

generate_release_notes() {
    local version="$1"
    local previous_version="$2"
    local format="${3:-markdown}"
    local use_ai="${4:-true}"
    
    local since_tag=""
    if [[ -n "$previous_version" ]]; then
        since_tag="$previous_version"
    fi
    
    # Get commit information
    local commits=$(get_commits_since_tag "$since_tag" "%s")
    local commit_count=$(echo "$commits" | wc -l)
    
    case "$format" in
        markdown)
            generate_markdown_notes "$version" "$previous_version" "$since_tag" "$use_ai"
            ;;
        github)
            generate_github_notes "$version" "$previous_version" "$since_tag" "$use_ai"
            ;;
        text)
            generate_text_notes "$version" "$previous_version" "$since_tag" "$use_ai"
            ;;
    esac
}

generate_markdown_notes() {
    local version="$1"
    local previous_version="$2"
    local since_tag="$3"
    local use_ai="$4"
    
    echo "# Release $version"
    echo ""
    
    # AI-generated summary
    if [[ "$use_ai" == "true" ]]; then
        local commits=$(get_commits_since_tag "$since_tag" "%s")
        local ai_summary=$(generate_ai_summary "$version" "$commits" "$previous_version")
        if [[ -n "$ai_summary" ]]; then
            echo "$ai_summary"
            echo ""
        fi
    fi
    
    # What's Changed section
    echo "## What's Changed"
    echo ""
    categorize_changes "$since_tag"
    echo ""
    
    # Links section
    if [[ -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
        echo "## 🔗 Links"
        echo ""
        if [[ -n "$previous_version" ]]; then
            echo "- [View Changes]($(get_github_compare_url "$previous_version" "$version"))"
        fi
        echo "- [Docker Hub](https://hub.docker.com/r/picklewagon/cardalmanac-app)"
        echo "- [Documentation](https://github.com/$GITHUB_OWNER/$GITHUB_REPO/blob/main/README.md)"
        echo ""
    fi
    
    # Docker info
    get_docker_image_info "$version"
    echo ""
    
    # Installation section
    echo "## 🚀 Installation"
    echo ""
    echo "### Docker (Recommended)"
    echo "\`\`\`bash"
    echo "docker pull picklewagon/cardalmanac-app:$version"
    echo "make upd  # Start minimal environment"
    echo "\`\`\`"
    echo ""
    echo "### Full Development Stack"
    echo "\`\`\`bash"
    echo "make upd-full  # Start complete local stack"
    echo "\`\`\`"
}

generate_github_notes() {
    local version="$1"
    local previous_version="$2"
    local since_tag="$3"
    local use_ai="$4"
    
    # AI-generated summary for GitHub
    if [[ "$use_ai" == "true" ]]; then
        local commits=$(get_commits_since_tag "$since_tag" "%s")
        local ai_summary=$(generate_ai_summary "$version" "$commits" "$previous_version")
        if [[ -n "$ai_summary" ]]; then
            echo "$ai_summary"
            echo ""
        fi
    fi
    
    echo "## What's Changed"
    categorize_changes "$since_tag"
    echo ""
    
    echo "## 🐳 Docker Images"
    echo "- \`picklewagon/cardalmanac-app:$version\`"
    echo "- \`picklewagon/cardalmanac-app:latest\`"
    echo ""
    
    if [[ -n "$previous_version" && -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
        echo "**Full Changelog**: $(get_github_compare_url "$previous_version" "$version")"
    fi
}

generate_text_notes() {
    local version="$1"
    local previous_version="$2"
    local since_tag="$3"
    local use_ai="$4"
    
    echo "Card Almanac Release $version"
    echo "================================"
    echo ""
    
    if [[ "$use_ai" == "true" ]]; then
        local commits=$(get_commits_since_tag "$since_tag" "%s")
        local ai_summary=$(generate_ai_summary "$version" "$commits" "$previous_version")
        if [[ -n "$ai_summary" ]]; then
            # Strip markdown formatting for text output
            echo "$ai_summary" | sed 's/[*_`]//g'
            echo ""
        fi
    fi
    
    echo "CHANGES:"
    echo "--------"
    categorize_changes "$since_tag" | sed 's/#//g'
    echo ""
    
    echo "DOCKER IMAGES:"
    echo "--------------"
    echo "picklewagon/cardalmanac-app:$version"
    echo "picklewagon/cardalmanac-app:latest"
}

# Main script
main() {
    local version=""
    local since_version=""
    local format="markdown"
    local use_ai="true"
    
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
            --no-ai)
                use_ai="false"
                shift
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --since)
                since_version="$2"
                shift 2
                ;;
            --claude-api-key)
                CLAUDE_API_KEY="$2"
                shift 2
                ;;
            [0-9]*.[0-9]*.[0-9]*)
                version="$1"
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
    
    # Get version if not provided
    if [[ -z "$version" ]]; then
        if command -v "$VERSION_SCRIPT" >/dev/null 2>&1; then
            version=$("$VERSION_SCRIPT" current)
        else
            log_error "Could not determine version. Please provide version argument."
            exit 1
        fi
    fi
    
    # Get previous version if not provided
    if [[ -z "$since_version" ]]; then
        since_version=$(git tag -l "*.*.*" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
    fi
    
    # Detect GitHub repository
    detect_github_repo
    
    # Validate format
    case "$format" in
        markdown|github|text)
            ;;
        *)
            log_error "Invalid format: $format. Use markdown, github, or text."
            exit 1
            ;;
    esac
    
    log_info "Generating release notes for version $version"
    if [[ -n "$since_version" ]]; then
        log_info "Comparing changes since version $since_version"
    fi
    
    # Generate release notes
    generate_release_notes "$version" "$since_version" "$format" "$use_ai"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi