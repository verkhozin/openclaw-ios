# Features V2 -- Full Roadmap

Everything discussed and confirmed. Grouped by priority.

## Core (MVP must-have)

### Agent Status & Activity
- Real-time status: idle, thinking, working, error
- Active subagents list with progress
- What agent is doing RIGHT NOW -- visible from any screen

### Stories / Quick Updates
- Agent posts "stories" -- short cards about what it did
- Swipe through like Instagram stories
- Each story has quick action: "View details" -> opens chat
- Agent decides when to post (task finished, email found, error happened)

### In-App Notifications
- Banner notifications inside the app (not iOS push, but internal)
- Quick reply from any screen without switching to chat
- "Agent needs approval" -> approve button right in the banner

### Memory Viewer
- Browse MEMORY.md in beautiful UI
- Edit: "forget this", "remember this"
- See what agent knows about you
- Unique feature -- no competitor has this

### File Library
- All files agent created, as a gallery
- Preview: HTML in WebView, images inline, code with highlighting
- Files served via Gateway HTTP, no local storage needed
- Filter by type: landings, PDFs, code, images

### Session Timeline
- Visual timeline of agent's day
- "09:00 -- checked email. 11:00 -- spawned 3 subagents. 14:00 -- generated landing."
- One glance = agent productivity

### Task Tracker (built-in)
- Simple kanban or list view
- User creates tasks manually OR agent creates them
- Agent can move tasks between columns (todo/doing/done)
- No need for Linear/Notion/external tools
- Stored in workspace as markdown, agent reads/writes

## Native Experience

### Share Card
- Long press agent response -> "Share"
- Generates beautiful card image with response + CLiOS branding
- Share to Twitter, Telegram, anywhere
- Free marketing every time someone shares

### Agent Profile
- Name, avatar (customizable)
- Stats: tasks completed, days active, messages exchanged
- Shareable profile card
- Multiple agents = multiple profiles

### Location-Aware (battery optimized)
- Significant location changes only (iOS API, no GPS polling)
- Agent knows you arrived at office/home/store
- Triggers: "you're near the store -- buy list: milk, bread"
- Toggle on/off per location type

## Productivity

### Quick Setup Wizard
- "Connect your email" -- wizard with fields, sends config to agent
- "Connect GitHub" -- same
- Agent handles all the technical setup
- User never touches config files

### Kanban Board
- Visual board for tasks
- Drag between columns
- Agent auto-updates based on activity
- Same data as Task Tracker, different view

### Prompt Library / Snippets
- Saved prompts: "Check email", "Generate landing", "Qualify startup"
- One tap to send
- User builds their collection

## Visual Polish

### Stories UI
- Circular avatars at top of dashboard (like Instagram/Telegram)
- Tap = open story card
- Auto-dismiss after viewed
- Unread indicator (ring around avatar)

### Animated Agent Avatar
- Idle: subtle breathing
- Thinking: pulsing
- Working: active movement
- Error: shake
- Done: checkmark burst

### Sound Design
- Soft tone on task completion (like AirDrop)
- Optional, off by default

## Advanced (post-MVP)

### PiP Chat
- Minimize chat to floating bubble
- Cool idea but complex -- research feasibility
- May need to render as Live Activity instead

### Terminal Access
- Defer. Agent can do everything and report back.
- Too niche, complex to implement securely.
- Maybe add as "developer mode" later.

### Service Integrations Setup
- Guided flows for adding email, calendar, GitHub
- Agent handles technical config
- User just provides credentials in a form
- Example: "Add email" -> fields: IMAP server, login, password -> agent configures msmtp/imaplib

## Competitor Advantages

What CLiOS has that NeuChat and Pawd don't:
- Digest / Stories -- visual briefing, not just chat
- Card system -- structured data rendering
- One-tap setup -- prompt-in-clipboard flow
- Memory Viewer -- edit agent's memory
- Task Tracker -- built-in, no external tools
- File Gallery -- browse agent's work
- Session Timeline -- agent productivity at a glance
- Beautiful design -- mesh gradients, animations, Apple-native feel
- Quick Setup Wizard -- guided service connections
- Smart Search -- one field searches chats, tasks, files, memory, commands
- VPS as backend -- all data on user's server, zero cloud dependency
