#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🔨 Building Disk Explorer in Release mode..."

# The built .app MUST live outside any cloud-synced folder (iCloud Drive, OneDrive, etc).
# macOS verifies the calling app's code signature by reading its binary off disk before
# granting certain requests (NSOpenPanel, FileManager.trashItem, etc). If that binary sits
# inside a live-synced folder, that read can stall indefinitely waiting on the sync daemon
# instead of returning instantly like it would from local disk. Building to ~/Applications
# keeps the source in iCloud Drive (fine, it's just text) while the runnable app itself
# is always local-only.
APP_OUTPUT_DIR="$HOME/Applications"
mkdir -p "$APP_OUTPUT_DIR"

# Build the Swift package
swift build -c release

# Ensure the app bundle directory structure exists
mkdir -p "$APP_OUTPUT_DIR/Disk Explorer.app/Contents/MacOS"
mkdir -p "$APP_OUTPUT_DIR/Disk Explorer.app/Contents/Resources"

# Copy the compiled binary into the app bundle
echo "📦 Copying binary to app bundle..."
cp .build/release/DiskExplorer "$APP_OUTPUT_DIR/Disk Explorer.app/Contents/MacOS/Disk Explorer"

# Copy the original application icon into the bundle. CFBundleIconFile below
# resolves this file as Contents/Resources/AppIcon.icns.
echo "🎨 Copying application icon..."
cp "Resources/AppIcon.icns" "$APP_OUTPUT_DIR/Disk Explorer.app/Contents/Resources/AppIcon.icns"

# Create Info.plist with necessary permissions for AppleScript
echo "📝 Creating Info.plist..."
cat << 'EOF' > "$APP_OUTPUT_DIR/Disk Explorer.app/Contents/Info.plist"
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
    <string>15.0</string>
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
touch "$APP_OUTPUT_DIR/Disk Explorer.app"

# Ad-hoc sign the entire bundle to satisfy macOS Gatekeeper and LaunchServices
echo "🔐 Ad-hoc signing the app bundle..."
xattr -cr "$APP_OUTPUT_DIR/Disk Explorer.app"
codesign --force --deep --sign - "$APP_OUTPUT_DIR/Disk Explorer.app"

echo "✅ Build complete! App installed to: $APP_OUTPUT_DIR/Disk Explorer.app"
echo "   Run it with: open \"$APP_OUTPUT_DIR/Disk Explorer.app\""
