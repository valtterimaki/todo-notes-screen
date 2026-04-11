#!/bin/bash
# Builds the TodoNotesScreen menu bar app and produces TodoNotesScreen.app
# Usage: ./build.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_ROOT/app"
APP_NAME="TodoNotesScreen.app"
BUNDLE="$PROJECT_ROOT/$APP_NAME"

echo "Building Swift app…"
cd "$APP_DIR"
swift build -c release

echo "Assembling app bundle…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

cp "$APP_DIR/.build/release/TodoNotesScreen" "$BUNDLE/Contents/MacOS/TodoNotesScreen"

cat > "$BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TodoNotesScreen</string>
    <key>CFBundleIdentifier</key>
    <string>com.todo-notes-screen.app</string>
    <key>CFBundleName</key>
    <string>Todo Notes Screen</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc sign so SMAppService (Launch at Login) works
codesign --sign - --force --deep "$BUNDLE"

echo ""
echo "Done! Built: $BUNDLE"
echo ""
echo "To install and run:"
echo "  cp -r '$BUNDLE' /Applications/"
echo "  open /Applications/$APP_NAME"
echo ""
echo "The app will appear in your menu bar."
