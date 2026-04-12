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
SETTINGS_PATH = CONFIG_DIR / "settings.json"

# OAuth scopes required for Google Tasks (read-only is sufficient)
GOOGLE_TASKS_SCOPES = ["https://www.googleapis.com/auth/tasks.readonly"]

# Output image resolution — default is MacBook Pro 16" native (3456×2234).
# Override with SCREEN_WIDTH / SCREEN_HEIGHT env vars if needed.
SCREEN_WIDTH  = int(os.getenv("SCREEN_WIDTH",  "3456"))
SCREEN_HEIGHT = int(os.getenv("SCREEN_HEIGHT", "2234"))
