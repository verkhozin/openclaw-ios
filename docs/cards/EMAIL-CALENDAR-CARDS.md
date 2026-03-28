# Email & Calendar Cards — CLiOS Design Spec

> Service cards for the CLiOS iOS client. Each card is a compact, actionable unit.
> Format: codeblock with type prefix, key-value fields, separator `---`, actions list.

---

## Design Principles

- One card = one decision or one piece of awareness
- No information the user doesn't need in the next 30 seconds
- Actions must be doable with one thumb
- Text fields: truncate long values, never wrap to 3+ lines
- Timestamps: relative when < 24h ("2 hours ago"), absolute otherwise ("Mar 28")

---

# EMAIL CARDS

---

## email.inbox

**Purpose:** Notify about an incoming email. User decides: read, reply, archive, or ignore.

### Fields

| Field       | Required | Notes                                              |
|-------------|----------|----------------------------------------------------|
| from        | yes      | Display name preferred over raw address            |
| subject     | yes      | Truncate at ~60 chars                              |
| preview     | yes      | First 1–2 lines of body, plain text, no HTML       |
| time        | yes      | Relative or absolute timestamp                     |
| account     | no       | Show only if user has multiple email accounts      |
| thread_size | no       | Show if > 1 message: "4 messages in thread"        |
| label       | no       | Urgent / Newsletter / etc. — only if agent-tagged  |

### Visual Layout

```
[from]                          [time]
[subject]
[preview — 2 lines max]
---
[actions]
```

Accent: thin left border color-coded by label (red = urgent, grey = default).
No avatar. No thread expansion inline.

### Actions

| Action  | Behavior                            |
|---------|-------------------------------------|
| Reply   | Open agent compose with quoted body |
| Archive | Archive immediately, dismiss card   |
| Open    | Deep-link to email in mail client   |

### Example

```card:email.inbox
from: Pavel Smirnov
subject: Re: Project estimate — final numbers
preview: Hey, reviewed your doc. Numbers look good overall, one concern about the timeline for phase 2...
time: 14 minutes ago
thread_size: 3
---
actions: Reply, Archive, Open
```

---

## email.draft

**Purpose:** Agent has composed an email on behalf of the user. User must approve before it sends.

This card is a confirmation gate — the email does NOT send until the user approves.

### Fields

| Field   | Required | Notes                                              |
|---------|----------|----------------------------------------------------|
| to      | yes      | Recipient display name or address                  |
| subject | yes      | Proposed subject line                              |
| preview | yes      | First 2–3 lines of the composed body               |
| account | no       | Which account will send (if multiple)              |
| context | no       | Brief note from agent: "In response to their ask about pricing" |

### Visual Layout

```
Draft ready to send
To: [to]
[subject]
[preview — 3 lines max]
[context — italic, if present]
---
[actions]
```

Visual indicator: "Draft ready" badge at top — distinguishes from incoming mail.

### Actions

| Action | Behavior                                  |
|--------|-------------------------------------------|
| Send   | Sends immediately, dismisses card         |
| Edit   | Opens draft in editable compose view      |
| Cancel | Discards draft, dismisses card            |

### Example

```card:email.draft
to: Anna Koroleva
subject: Proposal for mobile app development
preview: Hi Anna, following up on our call last Thursday. I've put together an initial scope for the mobile app project. The estimate for MVP is $45,000 covering design, iOS development...
context: Response to her inquiry from Mar 26
account: ea@verkhozin.ru
---
actions: Send, Edit, Cancel
```

---

## email.digest

**Purpose:** Periodic summary of inbox activity. No individual emails — just the shape of what's waiting.

Shown after batch processing or on schedule (morning digest, etc.).

### Fields

| Field    | Required | Notes                                          |
|----------|----------|------------------------------------------------|
| total    | yes      | Total unread count                             |
| urgent   | no       | Count of urgent/flagged items                  |
| senders  | no       | Top 2–3 sender names, comma-separated          |
| period   | no       | "Since 9:00 AM", "Last 6 hours", etc.          |
| accounts | no       | Break down by account if multiple              |

### Visual Layout

```
[total] new messages
[urgent: X urgent]  [period]
From: [senders]
---
[actions]
```

Minimal. Numbers are large. No list of subjects.

### Actions

| Action   | Behavior                              |
|----------|---------------------------------------|
| Open     | Open inbox in mail client             |
| Dismiss  | Dismiss card without action           |

### Example

```card:email.digest
total: 7
urgent: 2
senders: Pavel Smirnov, Notion, GitHub
period: Since 9:00 AM
---
actions: Open, Dismiss
```

---

## email.sent

**Purpose:** Confirm that an agent-sent email was delivered. Closes the loop.

Shown after agent sends on user's behalf. Short-lived card — user usually just dismisses.

### Fields

| Field   | Required | Notes                                      |
|---------|----------|--------------------------------------------|
| to      | yes      | Recipient                                  |
| subject | yes      | Subject line                               |
| time    | yes      | When it was sent                           |
| account | no       | Sending account                            |

### Visual Layout

```
Sent
To: [to]
[subject]
[time]
---
[actions]
```

Subtle — no urgency styling. Just a receipt.

### Actions

| Action | Behavior                       |
|--------|--------------------------------|
| View   | Open sent message in client    |
| OK     | Dismiss                        |

### Example

```card:email.sent
to: Anna Koroleva
subject: Proposal for mobile app development
time: Today at 11:47
account: ea@verkhozin.ru
---
actions: View, OK
```

---

# CALENDAR CARDS

---

## calendar.event

**Purpose:** Inform about an upcoming event. User confirms attendance, joins, or reschedules.

### Fields

| Field    | Required | Notes                                         |
|----------|----------|-----------------------------------------------|
| title    | yes      | Event name                                    |
| time     | yes      | Start time, e.g. "Today at 15:00" or "in 40 min" |
| duration | yes      | "30 min", "1 hour"                            |
| location | no       | Address or "Google Meet" / "Zoom"             |
| with     | no       | Attendee names, max 3, then "+ 2 more"        |
| notes    | no       | One-line description or agenda item           |
| link     | no       | Video call URL (shown as "Join" action)       |

### Visual Layout

```
[title]
[time]  •  [duration]
[location or link if present]
[with — if present]
---
[actions]
```

Compact. Time is largest text element.
Video link shown as a Join action button, not a raw URL.

### Actions

| Action    | Behavior                                 |
|-----------|------------------------------------------|
| Join      | Open video call link (if link present)   |
| Navigate  | Open location in Maps (if location)      |
| Reschedule| Trigger agent rescheduling flow          |
| Dismiss   | Dismiss reminder                         |

### Example

```card:calendar.event
title: Sync with Pavel — project scope
time: Today at 15:00
duration: 45 min
location: Google Meet
with: Pavel Smirnov
link: https://meet.google.com/abc-defg-hij
---
actions: Join, Reschedule, Dismiss
```

---

## calendar.conflict

**Purpose:** Two events overlap. User needs to resolve — one of them has to move or be declined.

### Fields

| Field    | Required | Notes                                              |
|----------|-----------|----------------------------------------------------|
| event_a  | yes       | Title of first event                               |
| event_b  | yes       | Title of second event                              |
| time     | yes       | Overlap window, e.g. "15:00–15:30"                 |
| overlap  | no        | Duration of overlap: "30 min overlap"              |
| priority | no        | Agent suggestion: "event_a has external attendees" |

### Visual Layout

```
Scheduling conflict
[time]

[event_a]
vs
[event_b]

[priority note — if present]
---
[actions]
```

Two-row event display, clearly opposed.
Agent hint below if available.

### Actions

| Action       | Behavior                                          |
|--------------|---------------------------------------------------|
| Keep first   | Agent cancels/reschedules second                  |
| Keep second  | Agent cancels/reschedules first                   |
| Reschedule   | Open both events for manual resolution            |

### Example

```card:calendar.conflict
event_a: Client call — Startup X
event_b: Team standup
time: 15:00 — 15:30
overlap: 30 min
priority: Client call has external attendees
---
actions: Keep first, Keep second, Reschedule
```

---

## calendar.daybrief

**Purpose:** Morning or on-demand overview of the day. One card, whole picture.

### Fields

| Field        | Required | Notes                                                |
|--------------|----------|------------------------------------------------------|
| date         | yes      | "Today, March 28" or "Tomorrow"                      |
| events_count | yes      | Number of scheduled events                           |
| free_hours   | no       | Hours of unblocked time                              |
| first_event  | no       | Title + time of first event                          |
| last_event   | no       | Title + time of last event                           |
| note         | no       | Agent observation: "Back-to-back 14:00–17:00"        |

### Visual Layout

```
[date]
[events_count] events  •  [free_hours] free

First: [first_event time] [first_event title]
Last:  [last_event time]  [last_event title]

[note — if present]
---
[actions]
```

Numbers prominent. Day-at-a-glance in 4 seconds.

### Actions

| Action     | Behavior                          |
|------------|-----------------------------------|
| Open       | Open today's calendar view        |
| Dismiss    | Dismiss card                      |

### Example

```card:calendar.daybrief
date: Today, March 28
events_count: 4
free_hours: 2.5
first_event: 10:00 — Investor prep call
last_event: 17:00 — Design review
note: Back-to-back from 14:00 to 16:30
---
actions: Open, Dismiss
```

---

## calendar.reminder

**Purpose:** Agent is prompting the user about something time-sensitive, not necessarily a calendar event.
Examples: "Your proposal deadline is tomorrow", "You said you'd reply to Pavel today."

### Fields

| Field   | Required | Notes                                                    |
|---------|----------|----------------------------------------------------------|
| title   | yes      | What the reminder is about                               |
| urgency | yes      | "today", "in 2 hours", "tomorrow" — drives visual weight |
| context | no       | One-line agent note: "You mentioned this on Mar 25"      |
| due     | no       | Specific time or date if known                           |

### Visual Layout

```
Reminder
[title]
[urgency / due]
[context — if present]
---
[actions]
```

If urgency = "today" or tighter: red accent or bold timestamp.

### Actions

| Action   | Behavior                                      |
|----------|-----------------------------------------------|
| Done     | Mark reminder complete, dismiss               |
| Snooze   | Remind again in 1 hour                        |
| Postpone | Reschedule to tomorrow morning                |

### Example

```card:calendar.reminder
title: Send updated estimate to Anna
urgency: today
due: Before 18:00
context: She asked for it on the call March 26
---
actions: Done, Snooze, Postpone
```

---

## Summary Table

| Card Type           | Core Info                    | Primary Action   | Max Fields Shown |
|---------------------|------------------------------|------------------|------------------|
| email.inbox         | From, subject, preview       | Reply / Archive  | 5                |
| email.draft         | To, subject, preview         | Send / Edit      | 5                |
| email.digest        | Count, urgent, senders       | Open             | 4                |
| email.sent          | To, subject, time            | OK               | 4                |
| calendar.event      | Title, time, duration        | Join / Navigate  | 5                |
| calendar.conflict   | Two events, overlap window   | Keep A / Keep B  | 4                |
| calendar.daybrief   | Count, free time, first/last | Open             | 5                |
| calendar.reminder   | Title, urgency               | Done / Snooze    | 4                |
