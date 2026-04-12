# todo-notes-screen

Fetches Google Tasks → renders HTML at native screen resolution → sets as macOS/Windows lock screen wallpaper.

## Pipeline
`main.py` → `core/tasks.py` → `core/renderer.py` → `template/lockscreen.html` → `platforms/macos.py` or `platforms/windows.py`

- `tasks.py` — OAuth + Google Tasks API; normalises into `{title, notes, due_label, due_state, subtasks[]}`
- `renderer.py` — Jinja2 → temp HTML; Playwright (headless Chromium) screenshots at `SCREEN_WIDTH × SCREEN_HEIGHT`
- `lockscreen.html` — sole visual file; authored at 1920 px wide, CSS `zoom`-scaled to native res
- `config.py` — paths, env vars; `SCREEN_WIDTH=3456`, `SCREEN_HEIGHT=2234` (MacBook Pro 16" native)

## CLI flags (main.py)
| Flag | Purpose |
|---|---|
| *(none)* | Full pipeline: fetch → render → set wallpaper |
| `--no-wallpaper` | Render only, skip wallpaper setter (Swift app calls this, then sets via NSWorkspace) |
| `--fingerprint` | Print SHA-256 of tasks JSON to stdout; used by Swift to skip renders when tasks unchanged |
| `--list-task-lists` | Print `[{id, title}]` JSON; used by Swift to populate list picker |

### Due state → appearance
| `due_state` | Trigger | Card | Badge |
|---|---|---|---|
| `none` | no due date | beige | none |
| `future` | >7 days | beige | ghost pill, outline border |
| `soon` | 0–7 days | beige | yellow `#fff673` pill |
| `overdue` | past due | orange `#ff784f` | black pill, alert icon |

### CSS token system (two-layer — do not break this)
**Base colors** (`--color-*`) — raw palette, never used directly in component rules:
`--color-beige: #d9d1cb`, `--color-black`, `--color-border-alpha: rgba(0,0,0,0.3)`, `--color-yellow: #fff673`, `--color-orange: #ff784f`

**State tokens** — semantic aliases defined in `:root` (default/none/future state), overridden per modifier class:
`--background`, `--text`, `--border`, `--badge-background`, `--badge-border`, `--badge-text`, `--card-border-width`

State classes (`.task-card--soon`, `.task-card--overdue`) override only the tokens that change. Components use only `var(--semantic-token)` — no hardcoded hex in component rules.

### Font
**Roboto Flex** via Google Fonts `@import`. Axes: `opsz, wdth, wght, GRAD, XOPQ, XTRA, YOPQ, YTAS, YTDE, YTFI, YTLC, YTUC`

`font-variation-settings` per element:
- **Heading / task title:** `'GRAD' 80, 'XOPQ' 96, 'XTRA' 468, 'YOPQ' 79, 'YTAS' 750, 'YTDE' -203, 'YTFI' 738, 'YTLC' 514, 'YTUC' 712, 'wdth' 100`
- **Badge / notes text:** same but `'wdth' 114, 'opsz' 45` (wider)
- **Order number circle:** same as badge but `'wdth' 70`

### Figma workflow
When the user shares a Figma URL or asks for a visual change: call `get_design_context` (nodeId + fileKey) and `get_variable_defs` before writing any CSS. The file has a "base colors" collection and a "states" collection — inspect both to map token values before touching the template.

## Swift menu bar app (macOS only)
Source: `app/Sources/TodoNotesScreen/`. Built app: `TodoNotesScreen.app` (install to `/Applications/`).

**Refresh loop (every 2 minutes):**
1. `main.py --fingerprint` → compare SHA-256; if unchanged, skip
2. `main.py --no-wallpaper` → render PNG
3. `WallpaperManager.set()` — copies PNG to a unique timestamped path (busts macOS URL cache), sets via `NSWorkspace.setDesktopImageURL`, cleans up stale copies

**Menu bar features:** status line, Refresh Now, Pause/Resume, task list picker, Launch at Login (`SMAppService`), Quit

**Hard-coded paths in `AppState.swift`** (update if project moves):
```
~/Documents/todo-notes-screen/venv/bin/python3
~/Documents/todo-notes-screen/main.py
```

**Build:**
```bash
./build.sh          # build
./watch-swift.sh    # auto-rebuild on source changes
```

## Scheduling
| Mechanism | Interval | Status |
|---|---|---|
| Swift menu bar app | 2 min (fingerprint-gated) | Active |
| `scheduling/macos_launchd.plist` | 30 min | **Not installed** (optional fallback) |
| `scheduling/windows_task.xml` | 30 min | Ready to import; needs path substitution |

**Install launchd (if needed):**
```bash
cp scheduling/macos_launchd.plist ~/Library/LaunchAgents/com.todo-notes-screen.update.plist
launchctl load ~/Library/LaunchAgents/com.todo-notes-screen.update.plist
```

## Windows implementation
`platforms/windows.py` uses WinRT `LockScreen.set_image_file_async()` — sets the **actual Windows lock screen** (not just desktop wallpaper, unlike macOS).

**To complete on Windows:**
1. `pip install winrt-Windows.System.UserProfile` (Windows-only, excluded from `requirements.txt`)
2. `playwright install chromium`
3. Edit `scheduling/windows_task.xml`: replace `C:\Users\YOU\Documents\todo-notes-screen` and venv python path
4. Import in Task Scheduler (`taskschd.msc` → Action → Import Task)
5. There is **no Windows menu bar app** — Task Scheduler is the only automation mechanism
6. OAuth first-run requires a browser; run `python main.py` once interactively to generate `token.json`
7. `SCREEN_WIDTH` / `SCREEN_HEIGHT` in `.env` or `config.py` should match the Windows display's native resolution

## Dev workflow
```bash
source venv/bin/activate
python dev.py   # Flask at http://localhost:8080
```
- Browser polls `/mtime` every 800ms; auto-reloads on `lockscreen.html` save
- `/refresh-tasks` re-fetches from Google without restarting
- **Port 5000 is blocked on the primary Mac** (AirPlay Receiver) — always use 8080. On Windows/other machines, port 5000 is fine.

## Key paths
| Purpose | Path |
|---|---|
| Config dir | `~/.config/todo-notes-screen/` |
| Output image | `~/.config/todo-notes-screen/current.png` |
| OAuth token | `~/.config/todo-notes-screen/token.json` |
| OAuth credentials | `~/.config/todo-notes-screen/credentials.json` |
| List selection | `~/.config/todo-notes-screen/settings.json` → `{"task_list": "NAME"}` |
| launchd logs | `~/.config/todo-notes-screen/launchd_stdout.log` / `launchd_stderr.log` |

## Setup from scratch
```bash
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
pip install flask                  # not in requirements.txt — add if recreating venv
playwright install chromium
# Copy credentials.json from Google Cloud Console to ~/.config/todo-notes-screen/
# Create .env with GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET
python main.py                     # first run triggers OAuth browser flow → saves token.json
```

## After making changes

Always tell the user what to do next after editing anything. Use this as the guide:

| What changed | What to do |
|---|---|
| `lockscreen.html` | If `dev.py` is running: save and check `http://localhost:8080` (auto-reloads). If not: `python dev.py` first. |
| `core/tasks.py`, `core/renderer.py`, `main.py`, `config.py` | `python main.py --no-wallpaper` to test the full render pipeline without touching the wallpaper. Check `~/.config/todo-notes-screen/current.png`. |
| Any Swift file (`app/Sources/…`) | `./build.sh`, then quit and reopen `TodoNotesScreen.app` from `/Applications/`. |
| `scheduling/macos_launchd.plist` | If launchd agent is loaded: `launchctl unload ~/Library/LaunchAgents/com.todo-notes-screen.update.plist && launchctl load …` to reload. |
| `CLAUDE.md` | No build step — but update the memory files under `~/.claude/projects/…/memory/` if the change is structural. |

If a change touches multiple areas, give the steps in order.

## Known issues
- **macOS Sonoma+ lock screen**: `osascript` sets the *desktop* wallpaper; on Sonoma+ the lock screen is separate. It mirrors via screensaver but isn't the true lock screen. Fix: `desktoppr` CLI or Shortcuts automation.
- **`flask` not in `requirements.txt`**: installed in venv manually; add `flask` when recreating.
- **`winrt` not in `requirements.txt`**: Windows-only; install manually on Windows.
- **Subtasks not rendered**: fetched and normalised but template doesn't display them.
- **No Windows menu bar equivalent**: Windows relies entirely on Task Scheduler (no fingerprint optimisation, no UI).
