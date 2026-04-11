# todo-notes-screen

Fetches your incomplete Google Tasks and renders them as a 1920×1080 PNG that is automatically set as your lock screen wallpaper — on both macOS and Windows.

```
todo-notes-screen/
├── .env.example             # environment variable template
├── requirements.txt
├── main.py                  # entry point
├── core/
│   ├── config.py            # loads .env, defines shared paths
│   ├── tasks.py             # Google Tasks API auth + fetching
│   └── renderer.py          # Jinja2 + Playwright → PNG
├── template/
│   └── lockscreen.html      # HTML/CSS lock screen template
├── platforms/
│   ├── macos.py             # osascript wallpaper setter
│   └── windows.py           # WinRT LockScreen API
└── scheduling/
    ├── macos_launchd.plist  # launchd agent (every 30 min)
    └── windows_task.xml     # Task Scheduler import (every 30 min)
```

---

## 1. Google Cloud setup

1. Go to <https://console.cloud.google.com/> and create a project (or reuse one).
2. Enable the **Google Tasks API** for the project.
3. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
4. Application type: **Desktop app**.
5. Download the JSON file and save it to:

   ```
   ~/.config/todo-notes-screen/credentials.json
   ```

6. On the **OAuth consent screen**, add your Google account as a test user (required while the app is in "Testing" mode).

---

## 2. Environment variables

Copy the example and fill in your values:

```bash
cp .env.example .env
```

`.env` contents:

| Variable                   | Description                                        |
|----------------------------|----------------------------------------------------|
| `GOOGLE_CLIENT_ID`         | OAuth client ID from the downloaded credentials    |
| `GOOGLE_CLIENT_SECRET`     | OAuth client secret from the downloaded credentials|
| `REFRESH_INTERVAL_MINUTES` | Informational; used by scheduler templates (default: 30) |

> The values for `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are also present in `credentials.json`. They are read from `.env` for convenience; `credentials.json` is what the OAuth library actually uses.

---

## 3. Python environment

```bash
# Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate        # macOS/Linux
# venv\Scripts\activate         # Windows

# Install Python dependencies
pip install -r requirements.txt

# Download the Chromium browser binary used by Playwright
# (this is a SEPARATE step — pip install alone is not enough)
playwright install chromium
```

> **Windows only:** also install the WinRT bindings:
> ```
> pip install winrt-Windows.System.UserProfile
> ```

---

## 4. Embedding the font (optional but recommended)

The template uses Inter as the typeface. Without an embedded font the browser
falls back to the system sans-serif, which looks fine but differs across
platforms.

**Steps to embed Inter:**

```bash
# 1. Download Inter Variable font
#    https://rsms.me/inter/ → "Download Inter"
#    Extract InterVariable.woff2 (or the .woff2 variant you prefer).

# 2. Base64-encode it
python3 -c "
import base64, pathlib
data = base64.b64encode(pathlib.Path('InterVariable.woff2').read_bytes()).decode()
print(data)
" > inter_b64.txt

# 3. In template/lockscreen.html, replace the src line inside @font-face:
#      src: url('data:font/woff2;base64,PASTE_BASE64_HERE') format('woff2');
#    with:
#      src: url('data:font/woff2;base64,<contents of inter_b64.txt>') format('woff2');
```

**Alternatively**, there is a copy of **Google Sans Flex** already in this repo under
`Google_Sans_Flex/`. To use it, base64-encode the `.ttf` there and update the
`font-family` CSS variable in the template to `'Google Sans Flex'`.

---

## 5. First run (triggers OAuth consent)

```bash
python3 main.py
```

On the first run a browser window will open asking you to grant Google Tasks
read access. After you approve, a token is saved to
`~/.config/todo-notes-screen/token.json` and subsequent runs are silent.

The generated image is written to `~/.config/todo-notes-screen/current.png`.

---

## 6. Scheduling (run every 30 minutes automatically)

### macOS — launchd

```bash
# 1. Edit the plist and replace /Users/YOU with your actual home directory
#    (or your real venv path)
nano scheduling/macos_launchd.plist

# 2. Install
cp scheduling/macos_launchd.plist \
   ~/Library/LaunchAgents/com.todo-notes-screen.update.plist

# 3. Load
launchctl load ~/Library/LaunchAgents/com.todo-notes-screen.update.plist

# To unload / disable
launchctl unload ~/Library/LaunchAgents/com.todo-notes-screen.update.plist
```

Logs are written to `~/.config/todo-notes-screen/launchd_stdout.log` and
`launchd_stderr.log`.

### Windows — Task Scheduler

1. Open `scheduling/windows_task.xml` in a text editor and update the two
   `<Command>` / `<WorkingDirectory>` paths to match your system.
2. Open **Task Scheduler** (`taskschd.msc`).
3. **Action → Import Task…** → select `windows_task.xml`.
4. On the **General** tab, configure the account under which the task runs.
5. Click **OK** — the task will fire at login and then every 30 minutes.

---

## 7. macOS lock screen note

`platforms/macos.py` sets the **desktop wallpaper** via System Events, which
is reflected on the lock screen on most macOS versions. On **macOS Sonoma
(14)+** Apple introduced a dedicated lock screen picture separate from the
desktop. If you need true lock-screen-only control on Sonoma, consider the
third-party CLI tool [`desktoppr`](https://github.com/scriptingosx/desktoppr)
or the Shortcuts automation approach.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `credentials.json not found` | Place the file at `~/.config/todo-notes-screen/credentials.json` |
| `playwright install chromium` not run | Run `playwright install chromium` in your activated venv |
| `osascript` permission denied | Grant Terminal (or the scheduler) **Automation** + **Accessibility** access in System Settings → Privacy & Security |
| Token expired / invalid | Delete `~/.config/todo-notes-screen/token.json` and re-run |
