"""Set the macOS lock screen wallpaper via osascript."""

from __future__ import annotations

import subprocess
from pathlib import Path


def set_lockscreen(image_path: Path) -> None:
    """
    Set the lock screen (and desktop) wallpaper on macOS.

    macOS does not expose a public API to set *only* the lock screen image;
    the closest available mechanism is setting the desktop picture via
    System Events, which is then mirrored to the lock screen on most
    macOS versions (Ventura and later store a separate lock screen, but
    the osascript approach still works for the desktop/screensaver combo).

    For macOS Sonoma+ you may want to use `desktoppr` or the
    `com.apple.systempreferences` scripting dictionary instead.
    """
    abs_path = str(image_path.resolve())

    # AppleScript: set every desktop's picture to the image
    script = (
        'tell application "System Events" to '
        f'set picture of every desktop to POSIX file "{abs_path}"'
    )

    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"osascript failed (exit {result.returncode}):\n{result.stderr.strip()}"
        )
