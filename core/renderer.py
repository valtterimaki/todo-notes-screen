from __future__ import annotations

import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader
from playwright.sync_api import sync_playwright

from core.config import OUTPUT_IMAGE_PATH, SCREEN_WIDTH, SCREEN_HEIGHT

# Resolve template directory relative to this file
_TEMPLATE_DIR = Path(__file__).parent.parent / "template"


def render_lockscreen(tasks: list[dict[str, Any]]) -> Path:
    """
    Render tasks into a 1920×1080 PNG lock-screen image.

    1. Injects the task list into lockscreen.html via Jinja2.
    2. Writes the result to a temporary file.
    3. Screenshots it with a headless Chromium browser at 1920×1080.
    4. Saves the result to OUTPUT_IMAGE_PATH and returns that path.
    """
    env = Environment(loader=FileSystemLoader(str(_TEMPLATE_DIR)), autoescape=True)
    template = env.get_template("lockscreen.html")

    scale = SCREEN_WIDTH / 1920
    rendered_html = template.render(
        tasks=tasks,
        updated_at=datetime.now().strftime("%A, %d %B %Y  %H:%M"),
        screen_width=SCREEN_WIDTH,
        screen_height=SCREEN_HEIGHT,
        scale=scale,
        # Height of the design canvas in 1920-wide CSS px so that zoom fills SCREEN_HEIGHT exactly
        effective_height=round(SCREEN_HEIGHT / scale),
    )

    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".html",
        prefix="temp_lockscreen_",
        delete=False,
        encoding="utf-8",
    ) as tmp:
        tmp.write(rendered_html)
        tmp_path = Path(tmp.name)

    try:
        _screenshot(tmp_path, OUTPUT_IMAGE_PATH)
    finally:
        tmp_path.unlink(missing_ok=True)

    return OUTPUT_IMAGE_PATH


def _screenshot(html_path: Path, output_path: Path) -> None:
    """Open html_path in a headless Chromium browser and save a full-page screenshot."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": SCREEN_WIDTH, "height": SCREEN_HEIGHT})
        page.goto(html_path.as_uri())
        # Wait for fonts / any CSS transitions to settle
        page.wait_for_load_state("networkidle")
        page.screenshot(path=str(output_path), full_page=False)
        browser.close()
