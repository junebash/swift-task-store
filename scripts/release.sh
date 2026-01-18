#!/bin/bash
set -euo pipefail

# Local release script for swift-task-store
# Usage: ./release.sh [--dry-run] [--version X.Y.Z] [--push] [--skip-enhance]
#
# Requires:
#   - git-cliff installed (brew install git-cliff)
#   - Claude Code CLI for changelog enhancement (optional)
#
# Options:
#   --dry-run       Show what would happen without making changes
#   --version       Override automatic version detection (e.g., --version 1.0.0)
#   --push          Push commits and tags to remote after release
#   --skip-enhance  Skip Claude enhancement, use raw git-cliff output
#   --help          Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default options
DRY_RUN=false
VERSION_OVERRIDE=""
PUSH=false
SKIP_ENHANCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --skip-enhance)
            SKIP_ENHANCE=true
            shift
            ;;
        --help)
            head -20 "$0" | tail -18
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

cd "$REPO_ROOT"

# Check prerequisites
if ! command -v git-cliff &> /dev/null; then
    echo "Error: git-cliff is not installed. Install with: brew install git-cliff" >&2
    exit 1
fi

# Get latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Latest tag: $LATEST_TAG"

# Check for commits since last tag
COMMITS_SINCE=$(git rev-list "${LATEST_TAG}..HEAD" --count 2>/dev/null || echo "0")
if [ "$COMMITS_SINCE" -eq "0" ]; then
    echo "No new commits since $LATEST_TAG. Nothing to release."
    exit 0
fi
echo "Commits since $LATEST_TAG: $COMMITS_SINCE"

# Determine next version
if [ -n "$VERSION_OVERRIDE" ]; then
    NEXT_VERSION="v${VERSION_OVERRIDE#v}"
else
    NEXT_VERSION=$("$SCRIPT_DIR/determine-version.sh" "$LATEST_TAG")
fi
echo "Next version: $NEXT_VERSION"

# Create temp directory for working files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

RAW_CHANGELOG="$TEMP_DIR/changelog_raw.md"
ENHANCED_CHANGELOG="$TEMP_DIR/changelog_enhanced.md"

# Generate raw changelog with git-cliff
echo ""
echo "Generating changelog with git-cliff..."
git-cliff "${LATEST_TAG}..HEAD" --config "$REPO_ROOT/cliff.toml" --tag "$NEXT_VERSION" -o "$RAW_CHANGELOG"

echo ""
echo "Raw changelog:"
echo "----------------------------------------"
cat "$RAW_CHANGELOG"
echo "----------------------------------------"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "[DRY RUN] Would enhance changelog (unless --skip-enhance)"
    echo "[DRY RUN] Would update RELEASES.md"
    echo "[DRY RUN] Would create commit and tag: $NEXT_VERSION"
    if [ "$PUSH" = true ]; then
        echo "[DRY RUN] Would push to remote"
    fi
    exit 0
fi

# Enhance changelog
if [ "$SKIP_ENHANCE" = true ]; then
    echo ""
    echo "Skipping enhancement, using raw changelog..."
    cp "$RAW_CHANGELOG" "$ENHANCED_CHANGELOG"
else
    echo ""
    echo "Enhancing changelog with Claude Code..."

    # Read existing RELEASES.md as style reference
    STYLE_REFERENCE=""
    if [ -f "$REPO_ROOT/RELEASES.md" ]; then
        STYLE_REFERENCE=$(head -100 "$REPO_ROOT/RELEASES.md")
    fi

    # Create prompt file for Claude
    PROMPT_FILE="$TEMP_DIR/prompt.md"
    cat > "$PROMPT_FILE" << 'PROMPT_EOF'
Transform this raw changelog into release notes matching the swift-task-store style.

## Style Reference (from existing RELEASES.md):

PROMPT_EOF
    echo "$STYLE_REFERENCE" >> "$PROMPT_FILE"
    cat >> "$PROMPT_FILE" << 'PROMPT_EOF'

## Raw Changelog:

PROMPT_EOF
    cat "$RAW_CHANGELOG" >> "$PROMPT_FILE"

    # Add full commit details so Claude can see commit bodies
    cat >> "$PROMPT_FILE" << 'PROMPT_EOF'

## Full Commit Details:

PROMPT_EOF
    git log "${LATEST_TAG}..HEAD" --format="### %s%n%n%b" >> "$PROMPT_FILE"

    cat >> "$PROMPT_FILE" << 'PROMPT_EOF'

## Instructions:

1. Match the style and structure of the existing RELEASES.md
2. Use clear headers like '### Features', '### Bug Fixes', '### Improvements'
3. Write brief but informative descriptions
4. Highlight any breaking changes prominently at the top
5. Do NOT include the version header (## vX.Y.Z) - just the content
6. Do NOT include horizontal rules (---)
7. If there are very few changes, keep the notes concise

Output ONLY the markdown content.
PROMPT_EOF

    # Try to use Claude Code CLI
    if command -v claude &> /dev/null; then
        echo "Using Claude Code CLI..."
        claude -p "$(cat "$PROMPT_FILE")" --output-format text > "$ENHANCED_CHANGELOG" 2>/dev/null || {
            echo ""
            echo "Claude Code CLI failed. Falling back to manual enhancement."
            echo ""
            echo "Please enhance the changelog manually. The prompt is at:"
            echo "  $PROMPT_FILE"
            echo ""
            echo "Save your enhanced changelog to:"
            echo "  $ENHANCED_CHANGELOG"
            echo ""
            read -p "Press Enter when done, or Ctrl+C to cancel..."

            if [ ! -f "$ENHANCED_CHANGELOG" ]; then
                echo "No enhanced changelog found. Using raw changelog."
                cp "$RAW_CHANGELOG" "$ENHANCED_CHANGELOG"
            fi
        }
    else
        echo ""
        echo "Claude Code CLI not found in PATH."
        echo ""
        echo "Options:"
        echo "  1. Copy the prompt below and paste into Claude"
        echo "  2. Re-run with --skip-enhance to use raw changelog"
        echo ""
        echo "=== PROMPT ==="
        cat "$PROMPT_FILE"
        echo "=== END PROMPT ==="
        echo ""
        echo "Paste the enhanced changelog below (end with Ctrl+D):"
        cat > "$ENHANCED_CHANGELOG"
    fi
fi

echo ""
echo "Enhanced changelog:"
echo "----------------------------------------"
cat "$ENHANCED_CHANGELOG"
echo "----------------------------------------"

# Prompt for confirmation with edit option
while true; do
    echo ""
    read -p "Proceed with release $NEXT_VERSION? [y/e/N] (e=edit) " -n 1 -r
    echo
    case $REPLY in
        [Yy])
            break
            ;;
        [Ee])
            ${EDITOR:-vim} "$ENHANCED_CHANGELOG"
            echo ""
            echo "Updated changelog:"
            echo "----------------------------------------"
            cat "$ENHANCED_CHANGELOG"
            echo "----------------------------------------"
            ;;
        *)
            echo "Release cancelled."
            exit 0
            ;;
    esac
done

# Update RELEASES.md
echo ""
echo "Updating RELEASES.md..."
"$SCRIPT_DIR/update-releases.sh" "$NEXT_VERSION" "$ENHANCED_CHANGELOG"

# Commit and tag
echo ""
echo "Creating commit and tag..."
git add RELEASES.md
git commit -m "chore(release): ${NEXT_VERSION}"
git tag -a "$NEXT_VERSION" -m "Release $NEXT_VERSION"

echo ""
echo "Release $NEXT_VERSION created locally."

if [ "$PUSH" = true ]; then
    echo ""
    echo "Pushing to remote..."
    git push origin HEAD --follow-tags
    echo "Pushed to remote."

    # Create GitHub release if gh is available
    if command -v gh &> /dev/null; then
        echo ""
        echo "Creating GitHub release..."
        gh release create "$NEXT_VERSION" \
            --title "$NEXT_VERSION" \
            --notes-file "$ENHANCED_CHANGELOG" \
            --latest
        echo "GitHub release created."
    else
        echo ""
        echo "Note: Install 'gh' CLI to auto-create GitHub releases."
    fi
else
    echo ""
    echo "To push: git push origin HEAD --follow-tags"
    echo "To create GitHub release: gh release create $NEXT_VERSION --title '$NEXT_VERSION' --generate-notes"
fi
