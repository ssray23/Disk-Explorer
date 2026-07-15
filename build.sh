#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🔨 Building Disk Explorer in Release mode..."

# Build the Swift package
swift build -c release

# Ensure the app bundle directory structure exists
mkdir -p "Disk Explorer.app/Contents/MacOS"
mkdir -p "Disk Explorer.app/Contents/Resources"

# Copy the compiled binary into the app bundle
echo "📦 Copying binary to app bundle..."
cp .build/release/DiskExplorer "Disk Explorer.app/Contents/MacOS/Disk Explorer"

# Touch the app bundle so Finder registers the changes
touch "Disk Explorer.app"

# Ad-hoc sign the entire bundle to satisfy macOS Gatekeeper and LaunchServices
echo "🔐 Ad-hoc signing the app bundle..."
xattr -cr "Disk Explorer.app"
codesign --force --deep --sign - "Disk Explorer.app"

echo "✅ Build complete! You can now launch 'Disk Explorer.app'."
