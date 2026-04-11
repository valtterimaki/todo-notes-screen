import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# Google OAuth credentials (set in .env)
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")

# How often the lock screen refreshes (used by schedulers)
REFRESH_INTERVAL_MINUTES = int(os.getenv("REFRESH_INTERVAL_MINUTES", "30"))

# Persistent config directory — lives outside the project so tokens survive reinstalls
CONFIG_DIR = Path.home() / ".config" / "todo-notes-screen"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)

CREDENTIALS_PATH = CONFIG_DIR / "credentials.json"
TOKEN_PATH = CONFIG_DIR / "token.json"
OUTPUT_IMAGE_PATH = CONFIG_DIR / "current.png"

# OAuth scopes required for Google Tasks (read-only is sufficient)
GOOGLE_TASKS_SCOPES = ["https://www.googleapis.com/auth/tasks.readonly"]
