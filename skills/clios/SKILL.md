---
name: clios
description: CLiOS iOS app integration. Use when the current session supports rich cards (caps include cards.v1). Provides card formats for structured data output (GitHub PRs, email drafts, task status, file previews, TODO lists, digest briefings, session titles). Do NOT use in Telegram/Discord/CLI sessions -- only when cards capability is present.
---

# CLiOS Card Output

When this session has `cards.v1` capability, output structured data as card codeblocks instead of plain text.

## Card Format

Standard markdown codeblock with `card:type` as language:

````
```card:github.pr
title: Fix hero animation
status: merged
repo: verkh-tech/site
```
````

Inside: key: value, one per line. Actions after `---` separator.

## Rules

1. **One type per situation.** Type follows from context unambiguously: working with PR -> github.pr, composing email -> email.draft.
2. **Digest over spam.** Multiple similar items -> one digest card (email.digest), NOT 5 separate email.inbox cards.
3. **Fallback.** If no type fits -- don't invent new ones. Plain text, app renders as text block.
4. **Actions via ---.** When user reaction needed (approve/reject/edit), add actions section after separator.
5. **Capability check.** Cards ONLY if client declared cards.v1 support. No caps -> plain text.

## Card Types

### github.pr
When: agent creates, finds, or discusses a PR.
```
number: 15
title: Fix hero animation
status: open|merged|closed
author: egor
repo: verkh-tech/site
branch: fix/hero-timing
targetBranch: main
ci: passed|failed|running
additions: 42
deletions: 8
```

### github.issue
When: agent works with GitHub issues.
```
title: Bug in login flow
labels: bug, urgent
assignee: egor
status: open|closed
```

### github.ci
When: agent checks or reports CI/CD.
```
status: pass|fail
duration: 3m 24s
logs: Build failed at step "test"
```

### email.inbox
When: agent shows incoming email.
```
from: alex@rivadata.com
subject: Partnership proposal
content: Hi Egor, I noticed...
time: 2026-04-02T14:00:00Z
isUnread: true
```

### email.draft
When: agent composed an email for sending.
```
to: alex@rivadata.com
subject: Partnership proposal
content: Hi Alex, I'd like to discuss...
---
actions: approve, edit, discard
```

### email.digest
When: agent summarizes multiple emails. ONE card, not one per email.
```
count: 5
urgent: 1
from: Gleb (urgent), Alex, Maria, GitHub (2)
subject: Partnership, Invoice, PR review, CI failed
```

### calendar.event
When: agent shows a meeting, call, or event.
```
title: Call with Gleb
date: 2026-04-03
startTime: 14:00
endTime: 15:00
duration: 1h
location: Zoom
attendees: Gleb, Egor
```

### calendar.conflict
When: two events overlap in time.
```
event1: Call with Gleb 14:00-15:00
event2: Team standup 14:30-15:00
suggestion: Move standup to 15:00
```

### linear.issue
When: agent works with any task tracker (Linear, GitHub Issues, ClickUp, Jira, Asana, Notion).
```
source: linear|github|clickup|jira|asana|notion
id: VERKH-42
title: Implement auth flow
status: backlog|todo|inProgress|done|cancelled
priority: urgent|high|medium|low|none
assignee: egor
labels: feature, ios
project: CLiOS
```

### file.preview
When: agent saves a file or shows a result.
```
path: landing/v4-flux.html
type: html|image|pdf|code
size: 51KB
url: http://gateway:port/__openclaw__/canvas/landing/v4-flux.html
```

### file.diff
When: agent shows changes to a file.
```
path: Services/GatewayService.swift
additions: 42
deletions: 8
summary: Added reconnect logic with exponential backoff
```

### lead
When: agent works with CRM/sales data.
```
name: Riva Data
round: $2.1M Seed
site: rivadata.com
status: qualified
contact: alex@rivadata.com
```

### task.status
When: subagent started or finished.
```
id: run-id
label: Generate FLUX landing
status: running|done|failed|killed
model: claude-sonnet-4-6
runtime: 3m 24s
tokens: 45000
```

### task.approval
When: agent needs permission for an action.
```
id: request-id
command: rm -rf /tmp/build
risk: low|medium|high
context: Cleaning build artifacts
---
actions: approve, deny
```

### todo
When: user asks for TODO list.
```
title: Today
items: finish verkh.tech|false, update CV|true, outreach agencies|false
updated: 2026-04-02T16:00:00Z
```
Items: `text|done` comma-separated. App renders interactive checklist.

### digest.morning
When: morning briefing.
```
date: 2026-04-03
greeting: Quiet day ahead
calendar: 2 meetings, first at 14:00
email: 5 new, 1 urgent from Gleb
tasks: 3 open
summary: Good time to focus on verkh.tech
```
App renders full-screen "at a glance" with mesh gradient.

### story
When: notable event completed (not routine).
```
title: Landing shipped
body: v4-flux.html generated, 977 lines
action: View file
action_target: file:landing/v4-flux.html
```

### notify.git
When: agent creates a branch, pushes commits, or triggers a deploy. Renders animated git graph in Dynamic Island (GitGraphView).

**type** determines the graph shape:
- `branch` — fork path from source branch to new branch (purple)
- `commit` — linear graph with commit nodes (green)
- `deploy` — commit graph + deploy node with dashed connector (blue)

```
type: commit
branch: feat/notifications
sourceBranch: main
commits: 3
deployTarget: staging
```

**Fields:**
- `type` — required: `branch`, `commit`, or `deploy`
- `branch` — required: branch name shown in label
- `sourceBranch` — required for `branch` type: parent branch name
- `commits` — required for `commit` and `deploy`: number of commit nodes (1, 3, 12, etc.)
- `deployTarget` — required for `deploy`: target environment name

**Examples:**

Branch created:
````
```card:notify.git
type: branch
branch: feat/notifications
sourceBranch: main
```
````

Commits pushed:
````
```card:notify.git
type: commit
branch: feat/notifications
sourceBranch: main
commits: 3
```
````

Deploy triggered:
````
```card:notify.git
type: deploy
branch: feat/notifications
sourceBranch: main
commits: 3
deployTarget: staging
```
````

### notify.workflow
When: agent starts a multi-agent workflow (pipeline). Renders animated DAG in Dynamic Island (AgentClusterView).

```
workflow: lead-gen
agents: 6
```

**Fields:**
- `workflow` — required: workflow/pipeline name
- `agents` — required: number of agents in the cluster

**Example:**
````
```card:notify.workflow
workflow: lead-gen
agents: 6
```
````

### notify.subagent
When: agent spawns a sub-agent or sub-agent completes. Renders typewriter task description with status indicator in Dynamic Island (SubAgentView).

```
status: running
task: Researching company background and extracting key decision makers
```

**Fields:**
- `status` — required: `running` (animated pulse + typewriter) or `done` (static green checkmark)
- `task` — required: description of what the sub-agent is doing/did (max 3 lines)

**Examples:**

Sub-agent started:
````
```card:notify.subagent
status: running
task: Browsing product page and extracting pricing information
```
````

Sub-agent finished:
````
```card:notify.subagent
status: done
task: Qualified 3 leads — Stripe, Vercel, Linear — confidence 87%, 74%, 91%
```
````

### notify
When: generic notification that doesn't need a visual graph — simple text banner. Use for events that don't fit git/workflow/subagent types.

```
kind: cron
title: Daily digest triggered
subtitle: 5 emails, 2 tasks
style: pill
```

**kind** values:

| kind | Icon | Color | Use when |
|------|------|-------|----------|
| `commit` | sparkles | orange | Standalone commit note (prefer `notify.git` for graph) |
| `deploy` | sparkles | orange | Quick deploy note (prefer `notify.git` for graph) |
| `agent` | sparkles | orange | Agent lifecycle |
| `task.done` | checkmark.circle | green | Task completed |
| `task.fail` | xmark.circle | red | Task failed |
| `cron` | clock | yellow | Cron job triggered |
| `system` | info.circle | gray | Generic (default) |

**style** values (optional, default `pill`):
- `pill` — capsule under Dynamic Island, least intrusive
- `card` — full-width card from top
- `island` — expands from Dynamic Island, most prominent

**Fields:**
- `kind` — required, determines icon/color
- `title` — required, main banner text
- `subtitle` — optional, secondary line
- `style` — optional (default: pill)

### session.title
When: first reply in a NEW session (not main). 3-5 word title.
```
title: Deploy verkh.tech landing
```
App uses this to name the chat. Not rendered visually.

## Detailed Card Specs

For full field specifications, read: `references/card-specs.md`
