#!/bin/bash
# Watches app/Sources/ for changes and rebuilds + reinstalls TodoNotesScreen.app.
# Requires fswatch: brew install fswatch
#
# Usage: ./watch-swift.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCES="$PROJECT_ROOT/app/Sources"
APP_NAME="TodoNotesScreen.app"
INSTALL_PATH="/Applications/$APP_NAME"

if ! command -v fswatch &>/dev/null; then
    echo "fswatch not found. Install it with: brew install fswatch"
    exit 1
fi

rebuild() {
    echo ""
    echo "── Change detected — rebuilding… ──────────────────────────"
    if "$PROJECT_ROOT/build.sh"; then
        echo "Stopping running app…"
        pkill -x TodoNotesScreen 2>/dev/null || true
        sleep 0.5
        echo "Installing to $INSTALL_PATH…"
        cp -r "$PROJECT_ROOT/$APP_NAME" "$INSTALL_PATH"
        echo "Launching…"
        open "$INSTALL_PATH"
        echo "── Done ────────────────────────────────────────────────────"
    else
        echo "── Build failed ────────────────────────────────────────────"
    fi
}

echo "Watching $SOURCES for changes…"
echo "Press Ctrl+C to stop."

fswatch -o "$SOURCES" | while read -r _; do
    rebuild
done
