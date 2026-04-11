# todo-notes-screen

Fetches Google Tasks → renders a 1920×1080 PNG → sets it as the macOS/Windows lock screen.

## Pipeline
`main.py` → `core/tasks.py` → `core/renderer.py` → `template/lockscreen.html` → `platforms/macos.py` or `platforms/windows.py`

- `tasks.py` — OAuth + Google Tasks API, normalises into `{title, notes, due_label, due_state, subtasks[]}`
- `renderer.py` — Jinja2 renders the HTML to a temp file; Playwright screenshots it at 1920×1080
- `lockscreen.html` — Jinja2 template; the only file that controls visual output
- `core/config.py` — paths, env vars (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `REFRESH_INTERVAL_MINUTES`)

## Visual design
Based on a Figma design (file key `fpqJ62AsC2kvd3OOIAaEUY`, frame node `1:3`).
- Warm beige background (`#d9d1cb`), large "Muista." heading, stacked card list on the left
- Cards overlap with the `margin-bottom: -24px` / `padding-bottom: 32px` accordion mechanic
- Each task card shows: numbered circle, title, optional due date badge
- Due date badge appearance is driven by `task.due_state`:
  - `none` — no badge shown
  - `future` (>7 days out) — ghost pill with outline
  - `soon` (0–7 days) — yellow `#fff673` pill
  - `overdue` (past due) — orange card `#ff784f`, black pill, alert icon

## Dev workflow
```
source venv/bin/activate
python dev.py   # Flask at http://localhost:8080
```
- Browser auto-reloads when `lockscreen.html` is saved (polls `/mtime` every 800ms)
- Hit `/refresh-tasks` to re-fetch from Google without restart
- Port 5000 is blocked on this Mac (AirPlay Receiver) — always use **8080**

## Key paths
| Purpose | Path |
|---|---|
| Config dir | `~/.config/todo-notes-screen/` |
| Output image | `~/.config/todo-notes-screen/current.png` |
| OAuth token | `~/.config/todo-notes-screen/token.json` |
| Credentials | `~/.config/todo-notes-screen/credentials.json` |

## Notes
- Task list name is **IMPORTANT** (not the default Google Tasks list)
- `flask` is in the venv but not in `requirements.txt` — add it if recreating the venv
- Font: **Roboto Flex** loaded via Google Fonts `@import` with axes `opsz, wdth, wght, GRAD, XOPQ, XTRA, YOPQ, YTAS, YTDE, YTFI, YTLC, YTUC`
- Scheduler plist exists at `scheduling/macos_launchd.plist` but has not been installed with `launchctl` 
