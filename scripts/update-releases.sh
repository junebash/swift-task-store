#!/bin/bash
set -euo pipefail

# Updates RELEASES.md with new release content
# Usage: ./update-releases.sh <version> <changelog-file>

VERSION="$1"
CHANGELOG_FILE="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASES_FILE="$REPO_ROOT/RELEASES.md"

# Read the enhanced changelog
CHANGELOG_CONTENT=$(cat "$CHANGELOG_FILE")

# Create new release entry
NEW_RELEASE="## ${VERSION}

${CHANGELOG_CONTENT}

---"

if [ -f "$RELEASES_FILE" ]; then
    # Read existing file
    EXISTING_CONTENT=$(cat "$RELEASES_FILE")

    # Extract header (first line) and rest of content
    HEADER=$(head -1 "$RELEASES_FILE")
    REST=$(tail -n +3 "$RELEASES_FILE")

    # Write new file with header, new release, then existing releases
    cat > "$RELEASES_FILE" << EOF
${HEADER}

${NEW_RELEASE}

${REST}
EOF
else
    # Create new RELEASES.md
    cat > "$RELEASES_FILE" << EOF
# swift-task-store Releases

${NEW_RELEASE}
EOF
fi

echo "Updated RELEASES.md with ${VERSION}"
