#!/bin/bash
set -euo pipefail

# Determines the next semantic version based on conventional commits
# Usage: ./determine-version.sh [latest-tag]
# If no tag provided, defaults to v0.0.0

LATEST_TAG="${1:-v0.0.0}"

# Strip 'v' prefix for calculation
CURRENT_VERSION="${LATEST_TAG#v}"

# Parse current version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Handle missing version components
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

# Get commits since last tag (or all commits if no tag)
if git rev-parse "$LATEST_TAG" >/dev/null 2>&1; then
    COMMITS=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"%s" 2>/dev/null || echo "")
else
    COMMITS=$(git log --pretty=format:"%s" 2>/dev/null || echo "")
fi

# If no commits, exit with current version
if [ -z "$COMMITS" ]; then
    echo "$LATEST_TAG"
    exit 0
fi

# Determine bump type based on conventional commits
BUMP="patch"

while IFS= read -r commit; do
    # Skip empty lines
    [ -z "$commit" ] && continue

    # Check for breaking changes (major bump)
    if [[ "$commit" =~ ^.*!: ]] || [[ "$commit" =~ BREAKING\ CHANGE ]]; then
        BUMP="major"
        break
    fi

    # Check for features (minor bump)
    if [[ "$commit" =~ ^feat ]]; then
        if [[ "$BUMP" != "major" ]]; then
            BUMP="minor"
        fi
    fi
done <<< "$COMMITS"

# Calculate new version
case "$BUMP" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

echo "v${MAJOR}.${MINOR}.${PATCH}"
