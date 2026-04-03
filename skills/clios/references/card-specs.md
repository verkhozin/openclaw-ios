# Card Specs (Detailed)

Full field specifications for all card types. Read this only when generating a card type you haven't used before.

## MVP Cards

### github.pr
Required: repo, title, status, url
Optional: branch, target, ci, diff, conflicts, reviewers, size (S/M/L/XL)
Status values: open (green), merged (purple), closed (red)
Tap action: opens url in browser

### email.draft
Required: to, subject, body
Optional: cc, bcc, from, reply_to
Actions: approve (sends email), edit (opens in chat for editing), discard
Body can contain newlines with \n
This is a GATE -- email does NOT send until user taps approve

### task.status
Required: id, label, status
Optional: model, runtime, tokens, result_preview
Status values: running (animated pulse), done (green check), failed (red), killed (gray)

### task.approval
Required: id, command
Optional: risk (low=blue, medium=orange, high=red), context, expiry
Actions: approve, deny
Always show -- this is highest priority card

### file.preview
Required: path, type
Optional: size, url, thumbnail
Type determines renderer: html=WebView, image=inline, pdf=PDFKit, code=syntax highlight
URL format: http://{gateway}/__openclaw__/canvas/{path}

### todo
Required: title, items
Optional: updated
Items: comma-separated "text|boolean" pairs
App renders interactive checklist, taps send "Mark done: {text}" to agent

### digest.morning
Required: date
Optional: greeting, calendar, email, tasks, weather, summary
App renders full-screen with mesh gradient background
Each field is tappable -- opens relevant section

### story
Required: title, body
Optional: action, action_target
Appears as circular avatar in stories bar
Auto-dismisses after user views
Use sparingly -- only for notable events

## Deferred Cards (not in MVP, but format defined)

### github.issue
Required: repo, number, title, status
Optional: labels, assignee, url

### github.ci
Required: repo, branch, status
Optional: failed_step, duration, jobs, url

### email.inbox
Required: from, subject, preview
Optional: timestamp, urgent (boolean)

### email.digest
Required: total, urgent_count
Optional: top_senders, action_needed

### calendar.event
Required: title, time
Optional: location, attendees, url

### linear.issue
Required: id, title, status
Optional: priority, assignee, labels

### usage.session
Required: percent
Optional: reset_in, model

### usage.weekly
Required: percent
Optional: reset_in, opus_hours

### gateway.status
Required: connected (boolean)
Optional: version, model, uptime, latency

## Infographics (custom user-defined)

### card:infographic
Required: id, title, viz, value
Optional: target, unit, period, updated, values, labels, trend, delta

Viz types: ring, bar, line, counter, streak, checklist, gauge

Example ring:
```
id: cal-tracker
title: Calories
viz: ring
value: 1840
target: 2200
unit: kcal
period: today
```
