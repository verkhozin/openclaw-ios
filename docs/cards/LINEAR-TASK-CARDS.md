# Card Specs: Linear + Task/Agent

Service cards for CLiOS — the iOS client for OpenClaw.
Designed for mobile-first task management: glanceable, actionable, no noise.

---

## Card Format Reference

```
```card:type
key: value
---
actions: button1, button2
```
```

---

## Linear Cards

---

### `linear.issue` — Single Linear Issue

**Purpose:** Show one Linear issue in enough detail to act on it from mobile.

#### Fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Issue identifier, e.g. `ENG-142` |
| `title` | yes | Issue title, max ~80 chars shown |
| `status` | yes | `backlog`, `todo`, `in_progress`, `done`, `cancelled` |
| `priority` | yes | `urgent`, `high`, `medium`, `low`, `no_priority` |
| `assignee` | no | Display name of assignee |
| `due` | no | Due date, ISO 8601 |
| `cycle` | no | Cycle name/number this issue belongs to |
| `label` | no | Single label (most relevant one) |
| `url` | no | Direct link for deep-link action |
| `description` | no | First ~120 chars of description for context |

#### Visual Design

- **Status badge** — left-edge color strip:
  - `backlog` → gray
  - `todo` → light blue
  - `in_progress` → blue
  - `done` → green
  - `cancelled` → muted/strikethrough
- **Priority indicator** — small icon/dot top-right:
  - `urgent` → red
  - `high` → orange
  - `medium` → yellow
  - `low` → gray
  - `no_priority` → none
- **Due date** — shown in red if overdue, orange if due today, gray otherwise
- **Assignee** — avatar initials or name chip
- **Label** — small tag below title

#### Actions

- `open` — open issue in Linear (deep link / browser)
- `assign_me` — assign to current user
- `set_status` — inline status picker (bottom sheet with status options)
- `set_priority` — inline priority picker
- `comment` — open comment composer
- `close` — mark done (one-tap)

#### Example

```card:linear.issue
id: ENG-142
title: Implement push notification opt-in flow
status: in_progress
priority: high
assignee: Egor V.
due: 2026-04-02
cycle: Sprint 14
label: feature
description: Users should be prompted on first launch to enable notifications...
url: https://linear.app/team/issue/ENG-142
---
actions: set_status, comment, open
```

---

### `linear.cycle` — Current Sprint / Cycle

**Purpose:** Sprint health at a glance. Is the team on track? What's blocking?

#### Fields

| Field | Required | Notes |
|---|---|---|
| `name` | yes | e.g. `Sprint 14` |
| `team` | yes | Team name |
| `starts` | yes | ISO 8601 date |
| `ends` | yes | ISO 8601 date |
| `total` | yes | Total issues in cycle |
| `done` | yes | Count completed |
| `in_progress` | yes | Count in progress |
| `todo` | yes | Count not started |
| `blocked` | no | Count with blockers (if Linear exposes this) |
| `scope_added` | no | Issues added after cycle start (scope creep signal) |
| `url` | no | Link to cycle in Linear |

#### Visual Design

- **Progress bar** — `done / total`, colored:
  - >75% → green
  - 50-75% → yellow
  - <50% with cycle ending soon → red
- **Days remaining** — shown top-right, red if <=2 days
- **Breakdown chips** — `done | in_progress | todo | blocked` as small count badges
- **Scope creep warning** — small badge if `scope_added > 0`
- No issue list here — that's clutter. Just aggregate counts.

#### Actions

- `view_issues` — opens filtered list of cycle issues
- `view_blocked` — filters to blocked issues only (shown only if `blocked > 0`)
- `open` — open cycle in Linear

#### Example

```card:linear.cycle
name: Sprint 14
team: Engineering
starts: 2026-03-24
ends: 2026-04-04
total: 18
done: 11
in_progress: 4
todo: 2
blocked: 1
scope_added: 2
url: https://linear.app/team/cycle/14
---
actions: view_issues, view_blocked, open
```

---

### `linear.digest` — Team Summary / Digest

**Purpose:** Morning briefing card. "What's the state of things?" in one glance.
No need to drill down — just enough to know if attention is needed.

#### Fields

| Field | Required | Notes |
|---|---|---|
| `team` | yes | Team or project name |
| `period` | yes | `today`, `this_week`, `cycle` |
| `done` | yes | Count completed in period |
| `in_progress` | yes | Count currently in progress |
| `blocked` | yes | Count blocked |
| `todo` | no | Count not started |
| `overdue` | no | Count past due date |
| `cycle_name` | no | Current cycle name if `period=cycle` |
| `cycle_ends` | no | Cycle end date |
| `top_blocker` | no | Title of the most critical blocked issue |
| `generated_at` | no | Timestamp for freshness signal |

#### Visual Design

- **Large number trio** — `done / in_progress / blocked` as prominent figures
- **Overdue count** — red badge if `overdue > 0`
- **Top blocker** — highlighted row below counts if present
- **Staleness indicator** — grayed out if `generated_at` > 4h ago
- **Cycle countdown** — shown if `period=cycle` and cycle ends within 3 days

#### Actions

- `refresh` — regenerate digest now
- `view_blocked` — jump to blocked issues (shown if `blocked > 0`)
- `view_overdue` — jump to overdue issues (shown if `overdue > 0`)

#### Example

```card:linear.digest
team: Engineering
period: cycle
cycle_name: Sprint 14
cycle_ends: 2026-04-04
done: 11
in_progress: 4
blocked: 1
todo: 2
overdue: 1
top_blocker: Auth token refresh race condition
generated_at: 2026-03-28T19:00:00Z
---
actions: refresh, view_blocked, view_overdue
```

---

## Task / Agent Cards

---

### `task.status` — Subagent Running or Completed

**Purpose:** Passive awareness. Something is happening. Let me know when done.
Not meant to be acted on — just informational with one optional abort.

#### Fields

| Field | Required | Notes |
|---|---|---|
| `task_id` | yes | Internal session/task ID |
| `label` | yes | Human-readable task name |
| `state` | yes | `running`, `done`, `failed`, `cancelled` |
| `started_at` | yes | ISO 8601 |
| `elapsed` | no | Elapsed time, human-readable, e.g. `2m 14s` |
| `progress` | no | 0-100 if deterministic, omit if unknown |
| `model` | no | Model running the task, e.g. `claude-sonnet-4` |
| `output_preview` | no | First ~100 chars of result (shown when `state=done`) |
| `error` | no | Short error message (shown when `state=failed`) |

#### Visual Design

- **State indicator** — animated pulse dot when `running`, checkmark when `done`, X when `failed`
- **Progress bar** — shown only if `progress` is set; indeterminate spinner otherwise
- **Elapsed time** — ticking live when `running`, frozen when `done`
- **Output preview** — appears below elapsed when `state=done`, truncated with "tap to expand"
- **Error row** — red text if `state=failed`
- **Model tag** — small muted label (contextual, not prominent)

#### Actions

- `abort` — kill running task (shown only when `state=running`)
- `view_result` — expand full output (shown when `state=done`)
- `retry` — re-run same task (shown when `state=failed`)
- `dismiss` — remove card from feed

#### Example

```card:task.status
task_id: subagent-62de0e68
label: Generate landing page copy for Loxa
state: running
started_at: 2026-03-28T20:10:00Z
elapsed: 1m 42s
model: claude-sonnet-4
---
actions: abort
```

```card:task.status
task_id: subagent-62de0e68
label: Generate landing page copy for Loxa
state: done
started_at: 2026-03-28T20:10:00Z
elapsed: 3m 08s
output_preview: Here is the landing page copy for Loxa. Hero: "Hire smarter, faster"...
---
actions: view_result, dismiss
```

---

### `task.approval` — Agent Requesting Permission

**Purpose:** Agent is paused and needs a human decision before continuing.
This is the highest-priority card type. Needs to feel urgent but not alarming.

#### Fields

| Field | Required | Notes |
|---|---|---|
| `task_id` | yes | Task waiting on approval |
| `label` | yes | Task label for context |
| `request` | yes | What the agent wants to do, plain language, max ~200 chars |
| `action_type` | yes | Category: `send_email`, `post`, `delete`, `external_call`, `file_write`, `other` |
| `risk` | yes | `low`, `medium`, `high` — drives visual urgency |
| `details` | no | Additional detail or preview (e.g. email body first 200 chars) |
| `expires_in` | no | Seconds until the request auto-cancels |
| `recipient` | no | Target of action (e.g. email address, API endpoint) |

#### Visual Design

- **Prominent header** — "Approval needed" in bold, full-width
- **Risk color band** — top border:
  - `low` → blue
  - `medium` → orange
  - `high` → red
- **Action type icon** — small icon representing the action category
- **Request text** — large, readable, center of card
- **Details** — collapsible section below request
- **Expiry countdown** — if `expires_in` set, live countdown in corner
- **Two clear buttons** — Allow and Deny, equal prominence, no ambiguity about which is which

#### Actions

- `allow` — approve and continue (primary)
- `deny` — reject, agent stops this action
- `allow_always` — approve this action type permanently for this task
- `view_task` — see full task context before deciding

#### Example

```card:task.approval
task_id: subagent-a1b2c3
label: Send outreach to Loxa founders
request: Send cold email to alex@loxa.io with subject "Quick question about your product stack"
action_type: send_email
risk: medium
recipient: alex@loxa.io
details: Hi Alex, I came across Loxa after your Series A announcement. We build custom mobile and AI products for early-stage startups...
---
actions: allow, deny, view_task
```

---

### `task.result` — Completed Task Output

**Purpose:** Deliver the result of a completed task in a structured, readable way.
Different from `task.status done` — this is the full result card, not a status update.

#### Fields

| Field | Required | Notes |
|---|---|---|
| `task_id` | yes | Source task |
| `label` | yes | Task label |
| `summary` | yes | 1-2 sentence result summary |
| `completed_at` | yes | ISO 8601 |
| `output_type` | yes | `text`, `file`, `list`, `data`, `mixed` |
| `output` | no | Main output content (text, markdown) |
| `files` | no | List of created/modified files |
| `elapsed` | no | Total time taken |
| `model` | no | Model used |
| `followup` | no | Suggested next action, plain text |

#### Visual Design

- **Summary** — prominent, always visible
- **Output** — collapsed by default, "Show output" tap to expand
- **File list** — each file as a chip with path, tap to view
- **Elapsed + model** — small metadata row at bottom
- **Followup suggestion** — if present, shown as a tappable prompt chip at bottom
- **Green checkmark** — top-right, clearly "done"

#### Actions

- `copy` — copy output text to clipboard
- `open_file` — open file (shown if `output_type=file`)
- `follow_up` — send followup prompt to agent (pre-filled with `followup` text if set)
- `share` — iOS share sheet for output
- `dismiss` — remove card

#### Example

```card:task.result
task_id: subagent-77fa12
label: Write landing page copy for Loxa
summary: Created landing page copy with hero, features, and CTA sections. Saved to workspace.
completed_at: 2026-03-28T20:13:08Z
output_type: file
files: openclaw-ios/loxa/landing-copy.md
elapsed: 3m 08s
model: claude-sonnet-4
followup: Review the copy and let me know if the tone needs adjusting
---
actions: open_file, follow_up, share, dismiss
```

---

### `task.queue` — Agent Task Queue

**Purpose:** How many tasks are waiting / running right now.
One card, always current. Good for persistent dashboard placement.

#### Fields

| Field | Required | Notes |
|---|---|---|
| `running` | yes | Count of actively running tasks |
| `queued` | yes | Count waiting to run |
| `done_today` | no | Completed today (progress signal) |
| `failed` | no | Failed count needing attention |
| `next_label` | no | Label of next queued task |
| `active_label` | no | Label of currently running task |
| `updated_at` | yes | ISO 8601, for freshness |

#### Visual Design

- **Two big numbers** — `running` and `queued` side by side, dominant
- **Done today** — smaller, below, muted (progress context)
- **Failed badge** — red, shown only if `failed > 0`
- **Active task** — one-liner showing what's running right now
- **Next task** — one-liner showing what's up next (if queue non-empty)
- **Idle state** — if `running=0` and `queued=0`, show "No active tasks" in muted text

#### Actions

- `view_all` — open full task list / session history
- `cancel_queue` — clear all queued (not running) tasks (shown if `queued > 0`)
- `abort_running` — abort current running task (shown if `running > 0`)

#### Example

```card:task.queue
running: 1
queued: 3
done_today: 7
failed: 0
active_label: Qualify leads from Riva batch #44
next_label: Generate outreach email for Dataform AI
updated_at: 2026-03-28T20:30:00Z
---
actions: view_all, cancel_queue
```

---

## Design Principles Applied

**Hierarchy:** Every card has one primary piece of information visible without scrolling. Everything else is secondary or collapsed.

**Action visibility:** Actions shown contextually — no "allow" button on a status card, no "abort" on a completed task. Irrelevant actions hidden, not grayed.

**Color discipline:** Color carries meaning consistently across all cards. Blue = active/info, green = done, orange = warning/medium risk, red = urgent/failed/overdue.

**Density calibration:** Linear cards (used for ongoing work) are denser — more fields visible. Task cards (event-driven) are sparser — one key message, fast action.

**No duplication:** `task.status` handles live monitoring. `task.result` handles the finished artifact. They don't overlap. `task.queue` is the macro view; `task.status` is the micro view.
