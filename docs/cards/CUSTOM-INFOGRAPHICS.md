# Custom Infographics

User-defined data cards that the agent tracks and updates automatically. Not hardcoded -- the user says "track my calories" and the agent creates a card, picks the right visualization, and keeps it current.

## How It Works

1. User says "track my daily calories" or "show me how many tasks I close per week"
2. Agent creates a persistent infographic card with a type, data source, and visualization
3. Agent updates the data on schedule (cron) or on events (task completed, meal logged, etc.)
4. Card lives on Dashboard and/or Widget

The agent decides: what visualization fits, when to update, what thresholds to set.

## Card Format

```card:infographic
id: cal-tracker-001
title: Calories Today
viz: ring
value: 1840
target: 2200
unit: kcal
period: today
updated: 2026-03-28T18:30:00Z
---
actions: log, detail, edit
```

## Visualization Types

### ring
Circular progress toward a target. Like Apple Watch activity ring.

Fields: value, target, unit
Best for: daily goals (calories, water, steps, focus hours)

### bar
Horizontal or vertical bars for comparison across days/weeks.

Fields: values (comma-separated), labels (comma-separated), unit
Best for: weekly task completion, commits per day, emails sent

### line
Sparkline trend over time. No axes, just the shape.

Fields: values (comma-separated), unit, trend (up/down/flat)
Best for: weight over 30 days, MRR trend, token spend over time

### counter
Single big number with optional delta badge.

Fields: value, delta, delta_direction (up/down), unit
Best for: total leads this month, open PRs, unread emails

### streak
Horizontal dots/squares (like GitHub contribution graph but one row).

Fields: days (comma-separated 0/1), current_streak, best_streak
Best for: workout streak, daily standup attendance, commit streak

### checklist
Progress bar with fraction. Visual count of done/total.

Fields: done, total, items (comma-separated labels, optional)
Best for: sprint progress, weekly goals, onboarding steps

### gauge
Semi-circle gauge with zones (green/yellow/red).

Fields: value, min, max, zones (green_end, yellow_end)
Best for: server CPU, budget remaining, API usage

## Persistence

Agent stores infographic definitions in workspace:
```
workspace/infographics/
  cal-tracker-001.json
  weekly-tasks.json
  commit-streak.json
```

Each file:
```json
{
  "id": "cal-tracker-001",
  "title": "Calories Today",
  "viz": "ring",
  "target": 2200,
  "unit": "kcal",
  "period": "daily",
  "dataSource": "user_input",
  "cronSchedule": null,
  "history": [
    {"date": "2026-03-27", "value": 2050},
    {"date": "2026-03-28", "value": 1840}
  ]
}
```

## Data Sources

How the agent gets the data:

- **user_input** -- user tells agent ("I had 600 cal lunch"). Agent parses and updates.
- **agent_computed** -- agent calculates from existing data (tasks closed from Linear, commits from GitHub)
- **api_poll** -- agent queries an API on schedule (weather, stock price, server health)
- **event_driven** -- agent updates when something happens (email arrives, subagent finishes)

## Agent Behavior

Agent doesn't wait to be asked. It:
- Notices patterns ("you've been logging calories for 3 days, want me to make a tracker?")
- Suggests visualizations ("your commit data looks good as a streak card")
- Sets thresholds ("you usually close 5 tasks/day, I'll set that as target")
- Alerts on anomalies ("you're at 80% calories and it's only 2pm")
- Adapts period (daily tracker resets at midnight, weekly on Monday)

## Widget Support

Any infographic can be pinned as a WidgetKit widget:
- Lock Screen (Accessory Circular): ring or counter only
- Small: any single viz
- Medium: up to 3 infographics side by side

## Dashboard Integration

Infographics appear as a scrollable row on the Dashboard, above Quick Actions.
User reorders by drag. Long press to edit or remove.

## Examples

### Fitness
```card:infographic
id: water-daily
title: Water
viz: ring
value: 6
target: 8
unit: glasses
period: today
```

### Productivity
```card:infographic
id: tasks-week
title: Tasks Closed
viz: bar
values: 3,5,4,7,2,0,0
labels: Mon,Tue,Wed,Thu,Fri,Sat,Sun
unit: tasks
period: this_week
```

### Business
```card:infographic
id: leads-month
title: Leads Qualified
viz: counter
value: 12
delta: +3
delta_direction: up
unit: leads
period: march
```

### Developer
```card:infographic
id: commit-streak
title: Commit Streak
viz: streak
days: 1,1,1,0,1,1,1,1,1,1,0,1,1,1
current_streak: 3
best_streak: 7
```

### Health
```card:infographic
id: weight-trend
title: Weight
viz: line
values: 82.1,81.8,82.0,81.5,81.3,81.6,81.0
unit: kg
trend: down
```
