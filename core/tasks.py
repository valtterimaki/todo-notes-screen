from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

from core.config import CREDENTIALS_PATH, TOKEN_PATH, GOOGLE_TASKS_SCOPES


def _get_credentials() -> Credentials:
    """Load stored credentials or run the OAuth flow to obtain new ones."""
    creds: Credentials | None = None

    if TOKEN_PATH.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), GOOGLE_TASKS_SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not CREDENTIALS_PATH.exists():
                raise FileNotFoundError(
                    f"credentials.json not found at {CREDENTIALS_PATH}.\n"
                    "Download it from Google Cloud Console and place it there."
                )
            flow = InstalledAppFlow.from_client_secrets_file(
                str(CREDENTIALS_PATH), GOOGLE_TASKS_SCOPES
            )
            creds = flow.run_local_server(port=0)

        TOKEN_PATH.write_text(creds.to_json())

    return creds


def _due_state(due_str: str | None) -> str:
    """Return urgency state for a due date: 'none', 'future', 'soon', or 'overdue'."""
    if not due_str:
        return "none"
    try:
        dt_utc = datetime.fromisoformat(due_str.replace("Z", "+00:00"))
        today = datetime.now(timezone.utc).date()
        days = (dt_utc.date() - today).days
        if days < 0:
            return "overdue"
        if days <= 7:
            return "soon"
        return "future"
    except ValueError:
        return "none"


def _format_due(due_str: str) -> str:
    """Format a Google Tasks due datetime string into a human-readable label.

    Google stores date-only tasks as midnight UTC; any non-midnight UTC time
    means the user set an explicit time of day, which we convert to local time.
    """
    try:
        dt_utc = datetime.fromisoformat(due_str.replace("Z", "+00:00"))
        today = datetime.now(timezone.utc).date()
        due_date = dt_utc.date()

        if due_date == today:
            date_label = "Today"
        elif (due_date - today).days == 1:
            date_label = "Tomorrow"
        elif (due_date - today).days == -1:
            date_label = "Yesterday"
        else:
            date_label = dt_utc.strftime("%-d %b")

        has_time = dt_utc.hour != 0 or dt_utc.minute != 0 or dt_utc.second != 0
        if has_time:
            local_time = dt_utc.astimezone().strftime("%H:%M")
            return f"{date_label} {local_time}"

        return date_label
    except ValueError:
        return due_str


def fetch_tasks() -> list[dict[str, Any]]:
    """Return all incomplete tasks from the 'IMPORTANT' Google Tasks list.

    Each top-level task dict contains:
      - title (str)
      - notes (str | None)
      - due_label (str | None)  — human-readable due date/time
      - subtasks (list[dict])  — incomplete child tasks with the same fields
    """
    creds = _get_credentials()
    service = build("tasks", "v1", credentials=creds)

    task_lists = service.tasklists().list(maxResults=100).execute()
    important_list = next(
        (tl for tl in task_lists.get("items", []) if tl.get("title") == "IMPORTANT"),
        None,
    )
    if not important_list:
        raise ValueError("No task list named 'IMPORTANT' found.")

    result = (
        service.tasks()
        .list(
            tasklist=important_list["id"],
            showCompleted=False,
            showHidden=False,
            maxResults=100,
        )
        .execute()
    )

    raw = [t for t in result.get("items", []) if t.get("status") != "completed"]
    raw.sort(key=lambda t: t.get("position", ""))

    # Normalise each task into the shape the template expects
    def _normalise(t: dict[str, Any]) -> dict[str, Any]:
        due_raw = t.get("due")
        return {
            "id": t.get("id", ""),
            "parent": t.get("parent"),
            "title": t.get("title", ""),
            "notes": t.get("notes") or None,
            "due_label": _format_due(due_raw) if due_raw else None,
            "due_state": _due_state(due_raw),
            "subtasks": [],
        }

    tasks_by_id: dict[str, dict[str, Any]] = {
        t["id"]: _normalise(t) for t in raw
    }

    top_level: list[dict[str, Any]] = []
    for t in raw:
        normalised = tasks_by_id[t["id"]]
        parent_id = t.get("parent")
        if parent_id and parent_id in tasks_by_id:
            tasks_by_id[parent_id]["subtasks"].append(normalised)
        else:
            top_level.append(normalised)

    return top_level
