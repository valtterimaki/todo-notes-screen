"""Entry point: fetch tasks, render image, set lock screen."""

from __future__ import annotations

import sys


def main() -> None:
    from core.tasks import fetch_tasks
    from core.renderer import render_lockscreen

    print("Fetching tasks from Google Tasks…")
    tasks = fetch_tasks()
    print(f"  {len(tasks)} incomplete task(s) found.")

    print("Rendering lock screen image…")
    image_path = render_lockscreen(tasks)
    print(f"  Image saved to: {image_path}")

    print("Applying lock screen…")
    platform = sys.platform

    if platform == "darwin":
        from platforms.macos import set_lockscreen
        set_lockscreen(image_path)
    elif platform == "win32":
        from platforms.windows import set_lockscreen
        set_lockscreen(image_path)
    else:
        print(f"  Platform '{platform}' is not supported. Image available at: {image_path}")
        return

    print("Done.")


if __name__ == "__main__":
    main()
