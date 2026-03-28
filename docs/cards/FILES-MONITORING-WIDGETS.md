# Card Specs: Files/Code, Monitoring/Usage, Widgets

CLiOS service card definitions for WidgetKit and in-chat rendering.
Format reference: ` ```card:type ` blocks with YAML-style fields, `---` separator before actions.

---

## FILES / CODE CARDS

---

### `file.preview`

Renders a visual preview of a file the agent produced or referenced.
Supports HTML landings, images (PNG/JPG/SVG/WEBP), and PDFs.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Display name of the file |
| `path` | string | Workspace-relative path |
| `mime` | string | MIME type: `text/html`, `image/*`, `application/pdf` |
| `preview_url` | string | URL or local file URI for the inline preview |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `size` | string | Human-readable size, e.g. `48 KB` |
| `lines` | number | Line count (for HTML/text) |
| `thumbnail_url` | string | Small static thumbnail for list view |
| `generated_at` | ISO 8601 | When the file was written |
| `description` | string | One-line agent note about the file |

**Visual**

- Full-width inline preview pane (WKWebView for HTML, PDFView for PDF, UIImageView for images)
- Header bar: filename + mime badge + size
- Footer: path in monospace, generated_at timestamp
- For HTML: safe sandboxed load, no JS execution
- For PDF: single-page thumbnail + swipe to scroll
- For images: pinch-to-zoom, tap to fullscreen

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `open` | Open | Open full-screen in-app viewer |
| `share` | Share | iOS share sheet |
| `copy_path` | Copy Path | Copy workspace path to clipboard |
| `regenerate` | Regenerate | Send follow-up prompt to agent to regenerate |
| `download` | Save to Files | Save via Files app |

**Example**

```card:file.preview
title: Landing Page - Loxa
path: workspace/projects/loxa/index.html
mime: text/html
preview_url: file:///root/.openclaw/workspace/projects/loxa/index.html
size: 12 KB
lines: 340
generated_at: 2026-03-28T18:42:00Z
description: Modern SaaS landing built from modern-saas template
---
actions: open, share, copy_path, regenerate, download
```

---

### `file.diff`

Shows a unified diff of changes the agent made to a file.
Used when the agent edits an existing file rather than creating one.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Display label, e.g. `"Updated SOUL.md"` |
| `path` | string | File path relative to workspace |
| `diff` | string | Unified diff content (raw `---/+++/@@` format) |
| `stats` | string | Summary string, e.g. `+12 -3 lines` |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `from_rev` | string | Previous revision hash or label |
| `to_rev` | string | New revision hash or label |
| `hunks` | number | Number of changed sections |
| `modified_at` | ISO 8601 | Timestamp of the edit |
| `reason` | string | Why the agent made this change |

**Visual**

- Compact diff view with syntax highlighting
  - Green background for additions (`+`)
  - Red background for deletions (`-`)
  - Gray for context lines
- Collapsible hunks if diff > 40 lines
- Header: filename + stats badge (`+12 -3`)
- Expandable: tap to see full diff inline
- Side-by-side toggle on iPad

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `view_file` | View File | Open current version in file.preview |
| `copy_diff` | Copy Diff | Copy raw diff to clipboard |
| `revert` | Revert | Ask agent to undo the change |
| `approve` | Approve | Acknowledge / mark as reviewed |

**Example**

```card:file.diff
title: Updated AGENTS.md
path: workspace/AGENTS.md
diff: |
  --- a/AGENTS.md
  +++ b/AGENTS.md
  @@ -12,6 +12,9 @@
   ## Session Startup
  +
  +Before doing anything else:
  +
   1. Read `SOUL.md` — this is who you are
stats: +3 -0 lines
hunks: 1
modified_at: 2026-03-28T19:10:00Z
reason: Added explicit ordering instruction for session startup
---
actions: view_file, copy_diff, revert, approve
```

---

### `file.saved`

Lightweight confirmation card shown after agent successfully writes a file.
Not a preview — just an acknowledgment with quick-access actions.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Filename or human label |
| `path` | string | Workspace-relative path |
| `operation` | enum | `created`, `updated`, `deleted` |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `size` | string | Final file size |
| `lines` | number | Total lines in saved file |
| `mime` | string | MIME type |
| `saved_at` | ISO 8601 | Write timestamp |
| `checksum` | string | SHA256 short hash (first 8 chars) |

**Visual**

- Compact single-row card (not full-screen)
- Left: file type icon (derived from mime or extension)
- Center: filename + path (truncated, monospace)
- Right: operation badge (`created` = blue, `updated` = orange, `deleted` = red)
- Subtle bottom row: size + saved_at
- Tap expands inline or opens file.preview (if previewable)

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `preview` | Preview | Open file.preview card inline |
| `copy_path` | Copy Path | Copy path to clipboard |
| `share` | Share | iOS share sheet |
| `open_folder` | Show in Files | Open parent folder in Files app |

**Example**

```card:file.saved
title: MEMORY.md
path: workspace/MEMORY.md
operation: updated
size: 3.2 KB
lines: 89
mime: text/markdown
saved_at: 2026-03-28T19:45:00Z
checksum: a3f91c7b
---
actions: preview, copy_path, share, open_folder
```

---

## MONITORING / USAGE CARDS

---

### `usage.session`

Shows consumption within the current 5-hour rolling session window.
Claude Max has a per-session message/token cap; this card tracks it live.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Internal session identifier |
| `used_pct` | number | 0-100, percent of session cap consumed |
| `messages_sent` | number | Messages sent in this session |
| `window_start` | ISO 8601 | When the 5h window opened |
| `window_end` | ISO 8601 | When the window resets |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `tokens_used` | number | Approximate tokens consumed |
| `tokens_cap` | number | Session token cap |
| `model` | string | Active model name |
| `cost_usd` | number | Estimated cost if metered |
| `remaining_min` | number | Minutes until window reset |

**Visual**

- Horizontal progress bar, color-coded:
  - 0-60%: green
  - 60-80%: yellow
  - 80-100%: orange/red
- Large percent figure centered above bar
- Below bar: `X messages` on left, `resets in Xh Xm` on right
- Window timeline: small start/end timestamps
- Model badge in top-right corner

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `refresh` | Refresh | Re-fetch current usage stats |
| `view_history` | History | Open usage history screen |
| `set_alert` | Set Alert | Configure threshold notification |

**Example**

```card:usage.session
session_id: sess_20260328_1800
used_pct: 62
messages_sent: 18
window_start: 2026-03-28T16:00:00Z
window_end: 2026-03-28T21:00:00Z
tokens_used: 31200
tokens_cap: 50000
model: claude-sonnet-4-6
remaining_min: 147
---
actions: refresh, view_history, set_alert
```

---

### `usage.weekly`

Tracks the rolling 7-day usage against the Claude Max subscription cap (20x multiplier).

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `week_start` | ISO 8601 | Start of the 7-day window |
| `week_end` | ISO 8601 | End of the 7-day window |
| `used_pct` | number | 0-100, percent of weekly cap consumed |
| `sessions_count` | number | Number of sessions this week |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `messages_total` | number | Total messages this week |
| `tokens_total` | number | Total tokens this week |
| `tokens_cap` | number | Weekly token cap |
| `daily_breakdown` | array | Per-day usage percentages `[12, 8, 20, ...]` |
| `projected_pct` | number | Projected end-of-week usage at current rate |
| `peak_day` | string | Day with highest usage, e.g. `"Mon"` |

**Visual**

- Large circular ring (SwiftUI `Circle` stroke, similar to Activity rings)
- Center: used_pct large + `of week cap` small
- Below ring: 7-bar mini histogram from daily_breakdown
- Bars colored by intensity (light = low, dark = high)
- Projection indicator if projected_pct > 90%
- Week range label at top: `Mar 24 - Mar 30`

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `refresh` | Refresh | Re-fetch stats |
| `view_breakdown` | Breakdown | Per-day detail view |
| `export` | Export | Export usage CSV |
| `set_alert` | Set Alert | Configure weekly threshold alert |

**Example**

```card:usage.weekly
week_start: 2026-03-23T00:00:00Z
week_end: 2026-03-29T23:59:59Z
used_pct: 41
sessions_count: 9
messages_total: 143
tokens_total: 198000
tokens_cap: 480000
daily_breakdown: [8, 12, 5, 18, 14, 20, 6]
projected_pct: 58
peak_day: Sat
---
actions: refresh, view_breakdown, export, set_alert
```

---

### `usage.alert`

Shown proactively when usage crosses a configured threshold.
High-priority card — rendered with warning styling.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `alert_type` | enum | `session`, `weekly` |
| `threshold_pct` | number | The threshold that was crossed |
| `current_pct` | number | Current usage percentage |
| `triggered_at` | ISO 8601 | When the alert fired |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | Human-readable alert message |
| `remaining_pct` | number | How much is left |
| `reset_at` | ISO 8601 | When the window resets |
| `suggestion` | string | Agent suggestion: pause, queue, etc. |
| `severity` | enum | `warning` (80%), `critical` (95%) |

**Visual**

- Card with colored left border: yellow (`warning`), red (`critical`)
- Top: alert type badge + severity label
- Main text: large `current_pct%` used with threshold note
- Progress bar (always red-toned in alert state)
- Bottom: reset_at countdown + suggestion text
- Subtle pulsing border animation for `critical`

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `dismiss` | Dismiss | Dismiss this alert |
| `snooze` | Snooze 30m | Suppress alerts for 30 minutes |
| `view_usage` | View Usage | Open full usage.session or usage.weekly card |
| `adjust_alert` | Adjust Threshold | Change the alert trigger percentage |

**Example**

```card:usage.alert
alert_type: session
threshold_pct: 80
current_pct: 83
triggered_at: 2026-03-28T20:15:00Z
message: Session usage at 83% - 17% remaining before reset
remaining_pct: 17
reset_at: 2026-03-28T21:00:00Z
suggestion: Consider pausing non-urgent tasks until window resets at 21:00
severity: warning
---
actions: dismiss, snooze, view_usage, adjust_alert
```

---

### `gateway.status`

Shows the current state of the OpenClaw gateway: online/offline, version, active model, node info.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `status` | enum | `online`, `offline`, `degraded`, `connecting` |
| `gateway_url` | string | Gateway endpoint (masked, last 8 chars shown) |
| `checked_at` | ISO 8601 | Last successful ping timestamp |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Gateway version string |
| `model` | string | Active model, e.g. `anthropic/claude-sonnet-4-6` |
| `node_name` | string | Connected node display name |
| `node_status` | enum | `connected`, `disconnected`, `tunneled` |
| `latency_ms` | number | Last ping latency in milliseconds |
| `uptime` | string | Gateway uptime, e.g. `3d 14h` |
| `error_msg` | string | Error description if status is `offline`/`degraded` |
| `channel` | string | Active channel: `telegram`, `discord`, etc. |

**Visual**

- Status indicator dot (green/red/yellow/gray) + large status text
- Two-column grid: version, model, node, latency
- Node row with connection type badge (`direct` / `tunnel` / `disconnected`)
- If offline: red card tint + error_msg in italic
- If degraded: yellow tint + description
- Last checked timestamp bottom-right, refreshes live

**Actions**

| Action ID | Label | Behavior |
|-----------|-------|----------|
| `refresh` | Refresh | Re-ping gateway |
| `reconnect` | Reconnect | Trigger gateway reconnect |
| `view_logs` | View Logs | Open gateway log viewer |
| `copy_url` | Copy URL | Copy gateway URL to clipboard |

**Example**

```card:gateway.status
status: online
gateway_url: ...85.254:18789
checked_at: 2026-03-28T20:30:00Z
version: 1.4.2
model: anthropic/claude-sonnet-4-6
node_name: Egors MacBook
node_status: tunneled
latency_ms: 42
uptime: 2d 6h
channel: telegram
---
actions: refresh, reconnect, view_logs, copy_url
```

---

## WIDGET CARDS (WidgetKit — display only, no interactions)

Widget cards are non-interactive. No `actions` block.
Rendered by WidgetKit on lock screen, home screen, and Standby.
All fields are display-only. No tap targets inside the widget.

---

### `widget.morning`

Morning briefing widget. Shows weather, first calendar event, and top task.
Intended for medium WidgetKit size (2x2 home screen grid).

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `date_label` | string | Formatted date, e.g. `"Saturday, Mar 28"` |
| `weather_temp` | string | Temperature with unit, e.g. `"+12 C"` |
| `weather_condition` | string | Short condition, e.g. `"Cloudy"` |
| `weather_location` | string | City name |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `weather_icon` | string | SF Symbol name for condition |
| `first_event_title` | string | Title of first calendar event today |
| `first_event_time` | string | Formatted time, e.g. `"11:00"` |
| `first_event_location` | string | Location or video call label |
| `top_task` | string | Top priority task or active agent summary |
| `task_source` | string | Origin: `"Linear"`, `"Reminders"`, `"Agent"` |
| `generated_at` | ISO 8601 | When this summary was composed |

**Visual (Medium widget, 338x158 pt)**

- Top row: date_label left, weather_temp + condition right
- Divider
- Middle row: first_event_time (bold) + first_event_title
  - Sub-row: first_event_location in gray
- Bottom row: top_task text with task_source badge
- Minimal, no icons beyond SF Symbols for weather
- Font: SF Pro, small caps for labels, regular for values
- Dark-mode aware

**Example**

```card:widget.morning
date_label: Saturday, Mar 28
weather_temp: +9 C
weather_condition: Partly Cloudy
weather_location: Moscow
weather_icon: cloud.sun.fill
first_event_title: Sync with design team
first_event_time: "12:00"
first_event_location: Google Meet
top_task: Review landing page for Loxa project
task_source: Agent
generated_at: 2026-03-28T07:00:00Z
```

---

### `widget.usage`

Compact usage rings for lock screen and Standby.
Designed for Accessory Circular (lock screen) and Small home screen widget.

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `session_pct` | number | 0-100, session usage percentage |
| `weekly_pct` | number | 0-100, weekly usage percentage |

**Optional fields**

| Field | Type | Description |
|-------|------|-------------|
| `session_label` | string | Override label, default `"Session"` |
| `weekly_label` | string | Override label, default `"Week"` |
| `session_reset_in` | string | Time until session reset, e.g. `"2h 14m"` |
| `model_short` | string | Short model name, e.g. `"Sonnet"` |
| `updated_at` | ISO 8601 | Last data refresh |

**Visual**

*Lock screen (Accessory Circular):*
- Single ring showing session_pct
- Center: large number + `%`
- Below ring: `Session` label in tiny caps

*Home screen Small (2x2):*
- Two concentric rings (outer = weekly, inner = session)
- Color coding: green < 60%, yellow < 80%, red >= 80%
- Center: model_short in small text
- Below outer ring: `Xh Xm` reset countdown
- Corner: last updated dot

*Lock screen Accessory Rectangular:*
- Two inline progress bars stacked
- `Session  [====------] 42%`
- `Week     [==--------] 18%`

**Example**

```card:widget.usage
session_pct: 62
weekly_pct: 41
session_label: Session
weekly_label: Week
session_reset_in: 2h 14m
model_short: Sonnet
updated_at: 2026-03-28T20:30:00Z
```

---

### `widget.tasks`

Shows active agents and their current task summary.
Designed for Medium home screen widget (2 rows of agents).

**Required fields**

| Field | Type | Description |
|-------|------|-------------|
| `agents` | array | List of active agent objects (see below) |
| `updated_at` | ISO 8601 | When the list was last fetched |

**Agent object fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `label` | string | yes | Short agent name or session label |
| `status` | enum | yes | `running`, `idle`, `waiting`, `done` |
| `task` | string | yes | Current or last task summary (truncated to ~60 chars) |
| `started_at` | ISO 8601 | no | When this agent started |
| `runtime_min` | number | no | Minutes running |

**Optional top-level fields**

| Field | Type | Description |
|-------|------|-------------|
| `total_agents` | number | Total active agents (if more than shown) |
| `title` | string | Widget header, default `"Active Agents"` |

**Visual (Medium widget)**

- Header: `"Active Agents"` left, agent count badge right
- Up to 3 agent rows:
  - Left: status dot (green=running, gray=idle, yellow=waiting, blue=done)
  - Center: `label` bold + `task` in gray below
  - Right: `Xm` runtime in small monospace
- If total_agents > 3: `+N more` footer row
- Empty state: `"No active agents"` centered in gray
- Updated_at in tiny text bottom-right
- Font: SF Pro Rounded for labels, monospace for times

**Example**

```card:widget.tasks
title: Active Agents
total_agents: 2
updated_at: 2026-03-28T20:28:00Z
agents:
  - label: Scout
    status: running
    task: Fetching YC W26 batch funding data
    started_at: 2026-03-28T20:10:00Z
    runtime_min: 18
  - label: Cards designer
    status: done
    task: Wrote FILES-MONITORING-WIDGETS.md
    started_at: 2026-03-28T20:00:00Z
    runtime_min: 30
```

---

## Summary Table

| Card Type | Interactive | Min Fields | Actions Count | Primary Visual |
|-----------|------------|-----------|---------------|----------------|
| `file.preview` | yes | 4 | 5 | Inline preview pane |
| `file.diff` | yes | 4 | 4 | Syntax-highlighted diff |
| `file.saved` | yes | 3 | 4 | Compact file row |
| `usage.session` | yes | 5 | 3 | Progress bar + % |
| `usage.weekly` | yes | 4 | 4 | Ring + histogram |
| `usage.alert` | yes | 4 | 4 | Bordered alert card |
| `gateway.status` | yes | 3 | 4 | Status dot + grid |
| `widget.morning` | no | 4 | - | Date/weather/event/task |
| `widget.usage` | no | 2 | - | Concentric rings |
| `widget.tasks` | no | 2 | - | Agent rows list |
