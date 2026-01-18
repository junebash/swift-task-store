# swift-task-store Justfile

# Default recipe: list available commands
default:
    @just --list

# Build the package
build:
    swift build

# Build in release mode
build-release:
    swift build -c release

# Run all tests
test:
    swift test

# Clean build artifacts
clean:
    swift package clean

# Create a release (dry run by default)
release *args:
    ./scripts/release.sh {{args}}

# Create a release (dry run)
release-dry:
    ./scripts/release.sh --dry-run

# Create and push a release
release-push:
    ./scripts/release.sh --push

# Create a release with a specific version
release-version version:
    ./scripts/release.sh --version {{version}}
