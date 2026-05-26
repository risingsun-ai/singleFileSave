#!/usr/bin/env bash
#
# web2offline.sh - Download web pages as self-contained offline files
#
# A standalone Bash script that downloads web URLs and saves them as
# single, self-contained offline files (HTML or Markdown) with:
# - Base64 inlined images for offline rendering
# - JavaScript stripped for security/cleanliness
# - CSS preserved for visual fidelity
# - Original source link injected at top-right
#
# Usage: web2offline.sh [OPTIONS] <URL>
#
# Author: Linux Systems Engineer
# License: MIT

set -euo pipefail

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

# Output format: html (default) or markdown
OUTPUT_FORMAT="html"

# Verbose/debug mode
VERBOSE=false

# Timeout for network requests (seconds)
TIMEOUT=30

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

die() {
    log_error "$@"
    exit 1
}

# =============================================================================
# Help Menu
# =============================================================================

show_help() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - Web Page to Offline File Converter

USAGE:
    ${SCRIPT_NAME} [OPTIONS] <URL>

DESCRIPTION:
    Downloads a web page and saves it as a self-contained offline file.
    All images are inlined as Base64 data URIs, JavaScript is stripped,
    and CSS is preserved for visual fidelity.

OPTIONS:
    -h, --help          Show this help message and exit
    -html, --html       Save as HTML file (default behavior)
    -md, --markdown     Save as Markdown file
    -v, --verbose       Enable verbose/debug output
    -V, --version       Show version information

EXAMPLES:
    # Download as HTML (default)
    ${SCRIPT_NAME} https://example.com

    # Download as Markdown
    ${SCRIPT_NAME} --markdown https://example.com/article

    # Verbose mode with explicit format
    ${SCRIPT_NAME} --verbose --html https://example.com/page

    # Specify output directory via environment
    OUTPUT_DIR=/tmp ${SCRIPT_NAME} https://example.com

ENVIRONMENT VARIABLES:
    OUTPUT_DIR          Directory to save output files (default: current dir)
    TIMEOUT             Network timeout in seconds (default: 30)

NOTES:
    - Output filename format: [Page_Title]_[YYYYMMDD_HHMMSS].[extension]
    - Page titles are sanitized for filesystem safety
    - All external resources (images, CSS) are inlined
    - JavaScript is removed for security

EOF
}

show_version() {
    echo "${SCRIPT_NAME} version ${VERSION}"
}

# =============================================================================
# String & Filename Utilities
# =============================================================================

# Sanitize string for use as filename
# Removes/replaces problematic characters
sanitize_filename() {
    local input="$1"
    local sanitized

    # Replace spaces and special chars with underscores
    sanitized=$(echo "$input" | tr -cs '[:alnum:]._-' '_' | sed 's/_\+/_/g' | sed 's/^_//;s/_$//')

    # Truncate if too long (max 200 chars for safety)
    if [[ ${#sanitized} -gt 200 ]]; then
        sanitized="${sanitized:0:200}"
    fi

    # Handle empty result
    if [[ -z "$sanitized" ]]; then
        sanitized="untitled"
    fi

    echo "$sanitized"
}

# Extract page title from HTML
extract_title() {
    local html="$1"
    local title

    # Try to extract <title> tag content
    title=$(echo "$html" | grep -oi '<title[^>]*>[^<]*</title>' | head -1 | sed 's/<title[^>]*>//i;s/<\/title>//i' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Fallback to h1 if no title tag
    if [[ -z "$title" ]]; then
        title=$(echo "$html" | grep -oi '<h1[^>]*>[^<]*</h1>' | head -1 | sed 's/<h1[^>]*>//i;s/<\/h1>//i' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi

    # Final fallback
    if [[ -z "$title" ]]; then
        title="webpage"
    fi

    echo "$title"
}

# Generate timestamp for filename
generate_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# =============================================================================
# Image Processing - Convert to Base64 Data URI
# =============================================================================

# Download and convert image URL to Base64 data URI
image_to_data_uri() {
    local img_url="$1"
    local img_data
    local mime_type
    local base64_data

    log_debug "Processing image: $img_url"

    # Skip data URIs (already inline)
    if [[ "$img_url" =~ ^data: ]]; then
        echo "$img_url"
        return 0
    fi

    # Skip empty or invalid URLs
    if [[ -z "$img_url" || "$img_url" =~ ^javascript: || "$img_url" =~ ^# ]]; then
        echo "$img_url"
        return 0
    fi

    # Resolve relative URLs
    if [[ "$img_url" =~ ^// ]]; then
        img_url="https:${img_url}"
    elif [[ ! "$img_url" =~ ^https?:// ]]; then
        # Relative URL - would need base URL context (simplified handling)
        log_debug "Skipping relative URL (needs base context): $img_url"
        echo "$img_url"
        return 0
    fi

    # Download image
    img_data=$(curl -sL --max-time 10 \
        -H "User-Agent: ${USER_AGENT}" \
        -H "Accept: image/webp,image/apng,image/*,*/*;q=0.8" \
        "$img_url" 2>/dev/null) || {
        log_debug "Failed to download image: $img_url"
        echo "$img_url"
        return 0
    }

    # Determine MIME type from content (magic bytes) or extension
    mime_type=$(file --mime-type -b <(echo "$img_data") 2>/dev/null || echo "application/octet-stream")

    # Validate it's an image
    if [[ ! "$mime_type" =~ ^image/ ]]; then
        log_debug "Not an image, skipping: $img_url (detected: $mime_type)"
        echo "$img_url"
        return 0
    fi

    # Convert to Base64
    base64_data=$(echo "$img_data" | base64 -w 0)

    echo "data:${mime_type};base64,${base64_data}"
}

# Process all images in HTML and inline them as Base64
inline_images() {
    local html="$1"
    local processed_html="$html"
    local img_urls
    local img_url
    local data_uri

    log_info "Inlining images..."

    # Extract all image URLs (src attributes) - use simpler grep pattern
    img_urls=$(echo "$html" | grep -oE 'src="[^"]*"' | sed 's/src="//;s/"$//' | sort -u)
    img_urls+=$'\n'$(echo "$html" | grep -oE "src='[^']*'" | sed "s/src='//;s/'$//" | sort -u)

    for img_url in $img_urls; do
        if [[ -n "$img_url" ]]; then
            log_debug "Found image: $img_url"
            data_uri=$(image_to_data_uri "$img_url")

            if [[ "$data_uri" != "$img_url" ]]; then
                log_debug "Replacing image with data URI"
                # Use awk for safer replacement to handle special characters
                processed_html=$(echo "$processed_html" | awk -v old="$img_url" -v new="$data_uri" '{gsub(old,new)}1')
            fi
        fi
    done

    # Also handle background-image in style attributes
    # This is a simplified approach - full CSS parsing would be more complex
    log_info "Images inlined successfully"
    echo "$processed_html"
}

# =============================================================================
# CSS Processing - Inline External Stylesheets
# =============================================================================

# Download and inline CSS from external stylesheet
inline_css_url() {
    local css_url="$1"
    local base_url="$2"
    local css_content

    log_debug "Processing CSS: $css_url"

    # Skip data URIs
    if [[ "$css_url" =~ ^data: ]]; then
        return 0
    fi

    # Resolve relative URLs
    if [[ "$css_url" =~ ^// ]]; then
        css_url="https:${css_url}"
    elif [[ "$css_url" =~ ^/ ]]; then
        # Absolute path - construct full URL
        local domain=$(echo "$base_url" | grep -oP 'https?://[^/]+')
        css_url="${domain}${css_url}"
    elif [[ ! "$css_url" =~ ^https?:// ]]; then
        # Relative path
        local base_path=$(echo "$base_url" | sed 's/[^/]*$//')
        css_url="${base_path}${css_url}"
    fi

    # Download CSS
    css_content=$(curl -sL --max-time 10 \
        -H "User-Agent: ${USER_AGENT}" \
        -H "Accept: text/css,*/*;q=0.1" \
        "$css_url" 2>/dev/null) || {
        log_debug "Failed to download CSS: $css_url"
        return 0
    }

    # Inline images in CSS as well (simplified - handles url() references)
    # This is a basic implementation; full CSS processing would be more complex
    echo "$css_content"
}

# Process HTML to inline external stylesheets
inline_stylesheets() {
    local html="$1"
    local base_url="$2"
    local processed_html="$html"

    log_info "Inlining stylesheets..."

    # Find all external stylesheet links - use simpler grep pattern
    local css_urls=$(echo "$html" | grep -oE 'href="[^"]*"' | grep -B1 'rel="stylesheet"' 2>/dev/null | grep 'href=' | sed 's/href="//;s/"$//' | sort -u)
    css_urls+=$'\n'$(echo "$html" | grep -i 'rel="stylesheet"' | grep -oE 'href="[^"]*"' | sed 's/href="//;s/"$//' | sort -u)

    for css_url in $css_urls; do
        if [[ -n "$css_url" ]]; then
            log_debug "Found stylesheet: $css_url"
            local css_content=$(inline_css_url "$css_url" "$base_url")

            if [[ -n "$css_content" ]]; then
                # Create style tag with inlined CSS
                local safe_name=$(echo "$css_url" | tr -cd 'a-zA-Z0-9')
                local style_tag="<style><!-- INLINED_CSS_${safe_name} -->${css_content}</style>"

                # Remove the original link tag
                processed_html=$(echo "$processed_html" | grep -v "href=\"${css_url}\"" || echo "$processed_html")

                # Insert before </head>
                processed_html=$(echo "$processed_html" | sed "s|</head>|${style_tag}</head>|")
            fi
        fi
    done

    log_info "Stylesheets inlined successfully"
    echo "$processed_html"
}

# =============================================================================
# JavaScript Removal
# =============================================================================

# Strip all JavaScript from HTML
strip_javascript() {
    local html="$1"
    local cleaned_html="$html"

    log_info "Stripping JavaScript..."

    # Remove <script>...</script> blocks (including multi-line)
    cleaned_html=$(echo "$cleaned_html" | perl -0777 -pe 's/<script[^>]*>.*?<\/script>//gis' 2>/dev/null || \
                   echo "$cleaned_html" | sed '/<script/,/<\/script>/d')

    # Remove script tags without closing (malformed)
    cleaned_html=$(echo "$cleaned_html" | sed '/<script[^>]*>/d')

    # Remove inline event handlers (onclick, onload, onerror, etc.)
    cleaned_html=$(echo "$cleaned_html" | sed -E 's/\s+on[a-zA-Z]+\s*=\s*"[^"]*"//gi')
    cleaned_html=$(echo "$cleaned_html" | sed -E "s/\s+on[a-zA-Z]+\s*=\s*'[^']*'//gi")
    cleaned_html=$(echo "$cleaned_html" | sed -E 's/\s+on[a-zA-Z]+\s*=\s*[^[:space:]>]+//gi')

    # Remove javascript: protocol in href/src
    cleaned_html=$(echo "$cleaned_html" | sed 's/href\s*=\s*["\x27]javascript:[^"\x27]*["\x27]/href="#"/gi')
    cleaned_html=$(echo "$cleaned_html" | sed "s/href\s*=\s*['\"]javascript:[^'\"]*['\"]/href=\"#\"/gi")

    # Remove noscript tags (optional - keeping content but removing wrapper)
    # cleaned_html=$(echo "$cleaned_html" | perl -0777 -pe 's/<noscript[^>]*>(.*?)<\/noscript>/\1/gis' 2>/dev/null || echo "$cleaned_html")

    log_info "JavaScript stripped successfully"
    echo "$cleaned_html"
}

# =============================================================================
# Source Link Injection
# =============================================================================

# Inject original source link at top-right of page
inject_source_link() {
    local html="$1"
    local source_url="$2"
    local injected_html="$html"

    log_info "Injecting source link..."

    # Create elegant, non-intrusive source link styled to not overlap content
    # Insert directly using sed with proper escaping
    local source_link='<div id="web2offline-source-link" style="position:fixed;top:10px;right:10px;z-index:999999;background:rgba(0,0,0,0.7);padding:8px 12px;border-radius:4px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;font-size:12px;line-height:1.4;box-shadow:0 2px 8px rgba(0,0,0,0.3);"><a href="'${source_url}'" target="_blank" rel="noopener noreferrer" style="color:#fff;text-decoration:none;display:flex;align-items:center;gap:6px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg><span>Original Source</span></a></div>'

    # Insert after opening <body> tag
    if echo "$injected_html" | grep -qi '<body'; then
        injected_html=$(echo "$injected_html" | awk -v link="$source_link" '/<[bB][oO][dD][yY]/{$0=$0 link}1')
    else
        # No body tag found - prepend to content
        injected_html="${source_link}${injected_html}"
    fi

    log_info "Source link injected successfully"
    echo "$injected_html"
}

# =============================================================================
# HTML to Markdown Conversion
# =============================================================================

# Basic HTML to Markdown conversion
# Note: This is a simplified converter; for production use, consider pandoc
html_to_markdown() {
    local html="$1"
    local md=""

    log_info "Converting to Markdown..."

    # Extract title
    local title=$(extract_title "$html")
    md="# ${title}\n\n"

    # Add source link
    md+="> **Original Source:** <${url}>\n\n---\n\n"

    # Basic tag conversions (simplified)
    local content="$html"

    # Remove head section
    content=$(echo "$content" | perl -0777 -pe 's/<head[^>]*>.*?<\/head>//gis' 2>/dev/null || echo "$content")

    # Remove script/style tags
    content=$(echo "$content" | perl -0777 -pe 's/<script[^>]*>.*?<\/script>//gis' 2>/dev/null || echo "$content")
    content=$(echo "$content" | perl -0777 -pe 's/<style[^>]*>.*?<\/style>//gis' 2>/dev/null || echo "$content")

    # Headers
    content=$(echo "$content" | sed -E 's/<h1[^>]*>([^<]*)<\/h1>/# \1/gi')
    content=$(echo "$content" | sed -E 's/<h2[^>]*>([^<]*)<\/h2>/## \1/gi')
    content=$(echo "$content" | sed -E 's/<h3[^>]*>([^<]*)<\/h3>/### \1/gi')
    content=$(echo "$content" | sed -E 's/<h4[^>]*>([^<]*)<\/h4>/#### \1/gi')
    content=$(echo "$content" | sed -E 's/<h5[^>]*>([^<]*)<\/h5>/##### \1/gi')
    content=$(echo "$content" | sed -E 's/<h6[^>]*>([^<]*)<\/h6>/###### \1/gi')

    # Bold and italic
    content=$(echo "$content" | sed -E 's/<strong[^>]*>([^<]*)<\/strong>/**\1**/gi')
    content=$(echo "$content" | sed -E 's/<b[^>]*>([^<]*)<\/b>/**\1**/gi')
    content=$(echo "$content" | sed -E 's/<em[^>]*>([^<]*)<\/em>/*\1*/gi')
    content=$(echo "$content" | sed -E 's/<i[^>]*>([^<]*)<\/i>/*\1*/gi')

    # Links
    content=$(echo "$content" | sed -E 's/<a[^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>/[\2](\1)/gi')
    content=$(echo "$content" | sed -E "s/<a[^>]*href='([^']*)'[^>]*>([^<]*)<\/a>/[\2](\1)/gi")

    # Images (with alt text as description)
    content=$(echo "$content" | sed -E 's/<img[^>]*alt="([^"]*)"[^>]*src="([^"]*)"[^>]*>/![\1](\2)/gi')
    content=$(echo "$content" | sed -E 's/<img[^>]*src="([^"]*)"[^>]*>/![](\1)/gi')

    # Lists
    content=$(echo "$content" | sed -E 's/<li[^>]*>([^<]*)<\/li>/- \1/gi')
    content=$(echo "$content" | sed -E 's/<ul[^>]*>//gi')
    content=$(echo "$content" | sed -E 's/<\/ul>//gi')
    content=$(echo "$content" | sed -E 's/<ol[^>]*>//gi')
    content=$(echo "$content" | sed -E 's/<\/ol>//gi')

    # Paragraphs
    content=$(echo "$content" | sed -E 's/<p[^>]*>([^<]*)<\/p>/\1\n\n/gi')

    # Line breaks
    content=$(echo "$content" | sed -E 's/<br[^>]*>/\n/gi')

    # Horizontal rules
    content=$(echo "$content" | sed -E 's/<hr[^>]*>/\n---\n/gi')

    # Code blocks and inline code
    content=$(echo "$content" | sed -E 's/<code[^>]*>([^<]*)<\/code>/`\1`/gi')
    content=$(echo "$content" | sed -E 's/<pre[^>]*>([^<]*)<\/pre>/```\n\1\n```/gi')

    # Blockquotes
    content=$(echo "$content" | sed -E 's/<blockquote[^>]*>([^<]*)<\/blockquote/>\n> \1\n/gi')

    # Remove remaining HTML tags
    content=$(echo "$content" | sed -E 's/<[^>]+>//g')

    # Clean up extra whitespace
    content=$(echo "$content" | sed '/^[[:space:]]*$/d')
    content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    md+="$content"

    log_info "Markdown conversion complete"
    echo -e "$md"
}

# =============================================================================
# Main Download & Processing Function
# =============================================================================

process_url() {
    local url="$1"
    local format="$2"
    local output_dir="${OUTPUT_DIR:-.}"
    local html_content
    local processed_html
    local final_content
    local page_title
    local sanitized_title
    local timestamp
    local output_file
    local extension

    log_info "Processing URL: $url"
    log_debug "Output format: $format"
    log_debug "Output directory: $output_dir"

    # Validate URL
    if [[ ! "$url" =~ ^https?:// ]]; then
        die "Invalid URL format. Must start with http:// or https://"
    fi

    # Ensure output directory exists
    mkdir -p "$output_dir"

    # Download the page
    log_info "Downloading page..."
    html_content=$(curl -sL --max-time "$TIMEOUT" \
        -H "User-Agent: ${USER_AGENT}" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.9" \
        "$url" 2>/dev/null) || die "Failed to download page: $url"

    if [[ -z "$html_content" ]]; then
        die "Downloaded content is empty"
    fi

    log_info "Page downloaded successfully (${#html_content} bytes)"

    # Extract page title
    page_title=$(extract_title "$html_content")
    log_debug "Extracted title: $page_title"

    # Process based on format
    if [[ "$format" == "html" ]]; then
        # Inline stylesheets
        processed_html=$(inline_stylesheets "$html_content" "$url")

        # Inline images
        processed_html=$(inline_images "$processed_html")

        # Strip JavaScript
        processed_html=$(strip_javascript "$processed_html")

        # Inject source link
        processed_html=$(inject_source_link "$processed_html" "$url")

        final_content="$processed_html"
        extension="html"
    else
        # For Markdown, first process HTML then convert
        processed_html=$(strip_javascript "$html_content")
        final_content=$(html_to_markdown "$processed_html")
        extension="md"
    fi

    # Generate filename
    sanitized_title=$(sanitize_filename "$page_title")
    timestamp=$(generate_timestamp)
    output_file="${output_dir}/${sanitized_title}_${timestamp}.${extension}"

    # Handle duplicate filenames
    if [[ -f "$output_file" ]]; then
        local counter=1
        while [[ -f "${output_dir}/${sanitized_title}_${timestamp}_${counter}.${extension}" ]]; do
            ((counter++))
        done
        output_file="${output_dir}/${sanitized_title}_${timestamp}_${counter}.${extension}"
    fi

    # Write output file
    log_info "Writing output file: $output_file"
    echo "$final_content" > "$output_file"

    # Verify file was written
    if [[ -f "$output_file" ]]; then
        local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
        log_info "Successfully saved: $output_file (${file_size} bytes)"
    else
        die "Failed to write output file"
    fi

    echo "$output_file"
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -V|--version)
                show_version
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            -html|--html)
                OUTPUT_FORMAT="html"
                shift
                ;;
            -md|--markdown)
                OUTPUT_FORMAT="markdown"
                shift
                ;;
            -*)
                die "Unknown option: $1. Use --help for usage information."
                ;;
            *)
                # Positional argument (URL)
                if [[ -z "${TARGET_URL:-}" ]]; then
                    TARGET_URL="$1"
                else
                    die "Multiple URLs provided. Please specify one URL at a time."
                fi
                shift
                ;;
        esac
    done

    # Validate URL was provided
    if [[ -z "${TARGET_URL:-}" ]]; then
        die "No URL provided. Use --help for usage information."
    fi
}

# =============================================================================
# Dependency Check
# =============================================================================

check_dependencies() {
    local missing_deps=()
    local required_tools=("curl" "grep" "sed" "awk" "base64" "date" "mkdir" "stat")

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_deps+=("$tool")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Missing required tools: ${missing_deps[*]}. Please install them to continue."
    fi

    # Check for perl (optional but recommended for better regex support)
    if ! command -v "perl" &>/dev/null; then
        log_info "Note: 'perl' not found. Some advanced features may be limited."
    fi

    log_debug "All dependencies satisfied"
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    parse_arguments "$@"
    check_dependencies

    log_info "Starting web2offline v${VERSION}"
    log_debug "Target URL: $TARGET_URL"
    log_debug "Output format: $OUTPUT_FORMAT"

    local output_file
    output_file=$(process_url "$TARGET_URL" "$OUTPUT_FORMAT")

    log_info "Done! Output file: $output_file"
    echo "$output_file"
}

# Run main function with all arguments
main "$@"
