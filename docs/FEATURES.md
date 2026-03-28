# Features

## 1. Voice Capture

Hold button, speak, release. Agent handles it. No app to open, no text to read.

Use cases:
- "Reschedule the meeting with Gleb to Friday"
- "Remind me to buy a gift for mom"
- "Check email and tell me if anything urgent"

Silent confirmation card appears in 3 seconds. No response wall.


## 2. Morning Card

One card on unlock. Answers "what matters right now?":
- Weather
- First meeting today
- One top task
- One unread from agent

Swipe to dismiss. Day started.


## 3. Approve/Deny on the Fly

Agent wants to send email, run a task, spend tokens. Push notification with two buttons: Yes / No. No need to open the app. Like a bank payment confirmation.

Examples:
- "Send outreach email to Riva Data? [Approve] [Deny]"
- "Run landing engineer on Sonnet? Est. 100k tokens [Go] [Skip]"
- "Subagent finished AURUM landing. [Preview] [Dismiss]"


## 4. Task Queue

Visible queue of everything the agent is working on. Not buried in chat history.

States: In Progress / Waiting / Done / Failed

Like a food delivery tracker, but for agent tasks. Each item shows:
- What it is (one line)
- Status + runtime
- Model + token count
- Tap to expand: full output, logs, files


## 5. Quick Actions Grid

4-6 customizable buttons. One tap = agent does it. No keyboard.

Default set:
- Check Email
- Status
- Run Build
- What's Next?

User configures their own. Each button = a canned prompt or cron trigger.


## 6. Rich Results (not text walls)

Agent saves files to workspace. App renders them natively:

- HTML landings: WebView preview with fullscreen button
- Images: inline thumbnail
- Code: syntax highlighted block with copy
- Structured data: native cards

Card format for structured output:
```
[card:lead]
name: Riva Data
round: $2.1M Seed
site: rivadata.com
status: qualified
[/card]
```

App parses, renders as a swipeable native card. Agent sends text, app renders UI.

Files served via Gateway HTTP: `http://gateway:port/__openclaw__/canvas/path/to/file`


## 7. Background Presence

Agent works while you're in other apps.

- Live Activity: "Building landing... 3/5 sections"
- Dynamic Island: compact progress indicator
- Finished: quiet haptic tap
- No need to watch the agent type


## 8. Widgets (WidgetKit)

Lock Screen:
- Usage ring (session % / weekly %)
- Active agents count

Home Screen Small:
- Next event + unread from agent

Home Screen Medium:
- Morning briefing card

Home Screen Large:
- TODO checklist with tappable checkboxes


## 9. Siri & Shortcuts

"Hey Siri, ask my agent what's in my email"

Shortcuts actions:
- Send Message to Agent
- Get Agent Status
- Run Quick Action
- Create Reminder via Agent

Automation triggers: time, location, NFC tag, Focus mode change.


## 10. Share Sheet

From any app: "Share to Agent"

Text, links, photos, PDFs. Agent receives with context menu:
- Summarize
- Save to memory
- Remind me later
- Translate
- "Deal with this"


## 11. Focus Integration

- Work: all notifications, full access
- Personal: urgent only
- Sleep: silence, agent queues for morning

Agent adapts behavior to current Focus mode automatically.


## 12. Service Cards

Agent actions with external services render as native cards, not text dumps.

**GitHub**
- PR card: title, status (open/merged/CI), diff stats, review status. Tap to open in Safari.
- Issue card: title, labels, assignee. Swipe to close/comment.
- CI run: pass/fail badge, duration, tap to see logs.
- Commit: hash, message, changed files count.

**Email**
- Inbox card: from, subject, first line preview, timestamp. Swipe right = reply via agent, left = archive.
- Draft preview: formatted email ready to send. Approve / Edit / Discard.
- "3 new emails, 1 urgent from X" -- summary card, not 3 separate messages.

**Calendar**
- Event card: title, time, location, attendees. Actions: reschedule, cancel, "prepare brief".
- Conflict alert: two overlapping events side by side with "resolve" button.
- "Tomorrow: 3 meetings" -- day summary card.

**Linear / Project Management**
- Issue card: ID, title, status, assignee, priority badge.
- Sprint/cycle progress bar.
- "5 issues moved to Done today" -- digest card.

**Web / Research**
- Search result cards: title, URL, snippet. Tap to open, long press to save.
- Screenshot preview of a website inline.

**Files / Code**
- File diff card: red/green lines, filename, tap to see full diff.
- Landing preview: thumbnail screenshot, tap for full WebView.
- "Saved to workspace/landing/v4-flux.html" -- with preview button.

Cards are parsed from structured blocks in agent output. Agent sends text with markup, app renders native UI.


## 13. Chat (when you need it)

Full chat is there, but it's not the primary interface.

- Streaming responses
- Syntax highlighted code blocks with copy
- Markdown rendering
- Diff view for file changes
- Swipe-to-reply
- Search history


## 13. Monitoring Dashboard

- Usage: session % + weekly % + Opus hours (ring visualization)
- Token spend per subagent
- Time to window reset
- Gateway status: online/offline, uptime, model
- Push alert: "80% limit used, 30 min to reset"


## 14. Cron Manager

Visual timeline (not a list). See when jobs fire.

- Toggle on/off with switch
- Run manually with one tap
- See last run result inline
- Drag to reschedule (stretch goal)


## 15. Privacy Controls

Explicit toggle for every data source:
- Calendar: read / write / off
- Contacts: read only / off
- Health: on / off
- Location: on / off

Action log: every external action the agent took (sent email, created event, pushed code). Auditable.

Guardrails: "Never send email without approval" -- configurable per action type.
