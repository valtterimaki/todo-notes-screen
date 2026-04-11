"""
Dev server for live-previewing lockscreen.html with real task data.

Usage:
    source venv/bin/activate
    python dev.py

Then open http://localhost:5000 in a browser.
The page auto-refreshes whenever you save template/lockscreen.html.
Tasks are fetched once on startup; hit /refresh-tasks to re-fetch.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from flask import Flask, jsonify
from jinja2 import Environment, FileSystemLoader

from core.tasks import fetch_tasks

app = Flask(__name__)

_TEMPLATE_DIR = Path(__file__).parent / "template"
_TEMPLATE_PATH = _TEMPLATE_DIR / "lockscreen.html"

# Cache tasks in memory so we don't hit the API on every page load
_tasks: list[dict] = []
_updated_at: str = ""


def _load_tasks() -> None:
    global _tasks, _updated_at
    print("Fetching tasks from Google Tasks…")
    _tasks = fetch_tasks()
    _updated_at = datetime.now().strftime("%A, %d %B %Y  %H:%M")
    print(f"  {len(_tasks)} task(s) loaded.")


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def preview() -> str:
    """Render the template with cached tasks on every request."""
    env = Environment(loader=FileSystemLoader(str(_TEMPLATE_DIR)), autoescape=True)
    template = env.get_template("lockscreen.html")
    html = template.render(tasks=_tasks, updated_at=_updated_at)

    # Inject auto-reload script just before </body>
    reload_script = """
<script>
  (function () {
    let lastMtime = null;
    async function check() {
      try {
        const r = await fetch('/mtime');
        const mtime = await r.text();
        if (lastMtime === null) { lastMtime = mtime; return; }
        if (mtime !== lastMtime) location.reload();
      } catch (_) {}
    }
    setInterval(check, 800);
  })();
</script>
"""
    return html.replace("</body>", reload_script + "</body>")


@app.route("/mtime")
def mtime() -> str:
    """Return template file modification time — polled by the browser."""
    return str(_TEMPLATE_PATH.stat().st_mtime)


@app.route("/refresh-tasks")
def refresh_tasks():
    """Re-fetch tasks from Google Tasks without restarting the server."""
    _load_tasks()
    return jsonify(count=len(_tasks), updated_at=_updated_at)


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    _load_tasks()
    print("\nDev server running at http://localhost:8080")
    print("Edit template/lockscreen.html — the browser will reload automatically.")
    print("Visit http://localhost:8080/refresh-tasks to re-fetch tasks.\n")
    app.run(host="localhost", port=8080, debug=False)
