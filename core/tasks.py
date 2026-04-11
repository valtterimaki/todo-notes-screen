from __future__ import annotations

import json
from pathlib import Path
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


def fetch_tasks() -> list[dict[str, Any]]:
    """Return all incomplete tasks from the user's default Google Tasks list."""
    creds = _get_credentials()
    service = build("tasks", "v1", credentials=creds)

    # Resolve the default task list (first in the list)
    task_lists = service.tasklists().list(maxResults=1).execute()
    items = task_lists.get("items", [])
    if not items:
        return []
    default_list_id = items[0]["id"]

    # Fetch all non-completed tasks; the API pages results but 100 is plenty for a lock screen
    result = (
        service.tasks()
        .list(
            tasklist=default_list_id,
            showCompleted=False,
            showHidden=False,
            maxResults=100,
        )
        .execute()
    )

    tasks = result.get("items", [])

    # Filter out any tasks that slipped through with a completed status
    tasks = [t for t in tasks if t.get("status") != "completed"]

    # Sort by position field (lexicographic string provided by the API)
    tasks.sort(key=lambda t: t.get("position", ""))

    return tasks
