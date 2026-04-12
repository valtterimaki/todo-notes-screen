"""Entry point: fetch tasks, render image, set lock screen."""

from __future__ import annotations

import argparse
import sys


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--no-wallpaper",
        action="store_true",
        help="Skip setting the wallpaper (used by the menu bar app, which sets it via NSWorkspace)",
    )
    parser.add_argument(
        "--list-task-lists",
        action="store_true",
        help="Print all Google Tasks lists as JSON and exit",
    )
    args = parser.parse_args()

    if args.list_task_lists:
        import json
        from core.tasks import get_task_lists
        print(json.dumps(get_task_lists()))
        return

    from core.tasks import fetch_tasks
    from core.renderer import render_lockscreen

    print("Fetching tasks from Google Tasks…")
    tasks = fetch_tasks()
    print(f"  {len(tasks)} incomplete task(s) found.")

    print("Rendering lock screen image…")
    image_path = render_lockscreen(tasks)
    print(f"  Image saved to: {image_path}")

    if not args.no_wallpaper:
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

    print("Done.")


if __name__ == "__main__":
    main()
