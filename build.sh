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

# Create Info.plist with necessary permissions for AppleScript
echo "📝 Creating Info.plist..."
cat << 'EOF' > "Disk Explorer.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.diskexplorer.app</string>
    <key>CFBundleName</key>
    <string>Disk Explorer</string>
    <key>CFBundleExecutable</key>
    <string>Disk Explorer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Disk Explorer needs permission to control the Finder in order to move protected applications and their caches to the Trash.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Disk Explorer needs access to scan your Desktop.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Disk Explorer needs access to scan your Documents.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Disk Explorer needs access to scan your Downloads.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>Disk Explorer needs access to scan removable volumes.</string>
    <key>NSNetworkVolumesUsageDescription</key>
    <string>Disk Explorer needs access to scan network volumes.</string>
</dict>
</plist>
EOF

# Touch the app bundle so Finder registers the changes
touch "Disk Explorer.app"

# Ad-hoc sign the entire bundle to satisfy macOS Gatekeeper and LaunchServices
echo "🔐 Ad-hoc signing the app bundle..."
xattr -cr "Disk Explorer.app"
xattr -cr "Disk Explorer.app"
codesign --force --deep --sign - "Disk Explorer.app"

echo "✅ Build complete! You can now launch 'Disk Explorer.app'."
