# Service Cards

Agent actions with external services render as native cards, not text walls. Each service is a plugin -- user enables only what they need.

## Core Services (MVP)

### GitHub
- PR: title, status, diff stats, CI badge, review status
- Issue: title, labels, assignee, swipe to close/comment
- CI run: pass/fail, duration, tap for logs
- Commit: hash, message, files changed

### Email
- Inbox: from, subject, preview line. Swipe right = reply via agent, left = archive
- Draft: formatted preview. Approve / Edit / Discard
- Digest: "3 new, 1 urgent from X" -- not 3 separate messages

### Calendar
- Event: title, time, location, attendees. Actions: reschedule, cancel, "prepare brief"
- Reminder: title, time, date, priority badge (high/medium/low), notes, calendar name
- Conflict: two events side by side with "resolve"
- Day summary: "Tomorrow: 3 meetings"

### Linear / Project Management
- Issue: ID, title, status, priority badge
- Sprint progress bar
- Digest: "5 issues moved to Done today"

### Files & Code
- Diff: red/green lines, filename
- Landing preview: thumbnail, tap for WebView
- "Saved to workspace/x.html" with preview button


## Extended Services

### Money
- Payment received: amount, from who, balance. Agent reminds to invoice.
- Subscription charged: "$200 Claude Max" -- auto-categorized
- Stripe dashboard: MRR card, recent charges

### Communications
- Slack/Discord: unread mentions summary. "3 mentions, 1 needs reply"
- WhatsApp/Telegram: messages from starred contacts. Quick reply.
- Twitter/X: mentions, DMs, post metrics

### DevOps
- Vercel/Netlify: deploy status, URL, build time. "verkh.tech deployed, 0 errors"
- Sentry: "3 new errors, 1 critical". Tap for stack trace.
- Server health: CPU, RAM, uptime. Red card if something's down.

### Documents
- Notion/Google Docs: "Doc edited by X", diff summary, quick comment
- PDF/contracts: preview, sign, send

### CRM / Sales
- Lead card: name, round, status, next step. Swipe to advance pipeline.
- Meeting prep: brief before call, notes after.

### AI / Usage
- Model usage across providers: Claude + OpenAI + Gemini spend combined
- Training jobs: status, metrics, alerts

### Smart Home
- HomeKit / Home Assistant: lights, thermostat, locks, cameras
- Agent controls home via node

### Travel
- Flight: gate, time, delays. Auto-parsed from email.
- Hotel: address, check-in, confirmation number.


## How Cards Work

Agent sends structured blocks in messages:

```
[card:github.pr]
repo: verkh-tech/site
title: Fix hero animation
status: merged
ci: passed
diff: +42 -8
[/card]
```

App parses, renders native SwiftUI card. Agent sends text, app renders UI.

Unknown card types fall back to formatted text block.

## Plugin Architecture

- Each service = independent module
- Settings > Services: toggle on/off per service
- Auth per service (OAuth, API key, or via Gateway)
- Agent decides which card to show based on context
- User never sees services they didn't enable
