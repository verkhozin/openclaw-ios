# Card Components

SwiftUI components for rendering service cards. Located in `CliOS/Components/Cards/`.

## Ready-made cards

### GitHubPRCard

Pull request card with colored header (`#232925`), status/CI badges, branch flow, diff stats.

```swift
GitHubPRCard(
    number: 128,
    title: "Fix hero animation",
    status: .open,              // .open (green) | .merged (purple) | .closed (red)
    author: "egor",
    repo: "verkh-tech/site",
    branch: "fix/hero",
    targetBranch: "main",
    ci: .passed,                // .passed (green) | .failed (red) | .running (yellow)
    additions: 42,
    deletions: 8
)
```

Layout:
- Header bar: GitHub icon + "Pull Request" + #number
- Title + colored diff stats (+/-) aligned to first baseline
- Branch flow: git-branch icon + source → target
- Footer: status badge + CI badge ... author · repo

### EmailCard

Full email view with markdown body rendering. Header color: `#4285F4` (Google blue).

```swift
EmailCard(
    type: .inbox,               // .inbox | .draft | .digest
    from: "Alex Kim <alex@co.com>",
    to: "egor@verkh.tech",
    subject: "Re: Partnership",
    content: "I think we should **move forward**...",  // markdown supported
    time: "10:42",
    isUnread: true,             // orange dot in header
    count: 3                    // message count badge (for digest)
)
```

Layout:
- Header bar: email type icon + "Email" + "· type" + unread dot + time
- From / To lines
- Subject (semibold)
- Divider
- Full markdown body (bold, italic, inline code, bullets, headings)

### CalendarCard

Two-column calendar event. Header color: `#EA4335` (Google red).

```swift
CalendarCard(
    title: "Design review",
    date: "Mar 29",
    startTime: "14:00",
    endTime: "15:00",
    duration: "1h",
    location: "Google Meet",    // hidden if empty
    attendees: ["Egor", "Alex"] // avatar circles, hidden if empty
)
```

Layout:
- Header bar: calendar icon + "Calendar" + date
- Left column: start time (22pt bold) + duration pill + end time
- Red vertical divider line
- Right column: title (17pt) + location + attendee avatar circles (colored initials, stacking with +N overflow)

### TaskCard

Universal task/issue card for any project management tool. Header color matches source.

Sources: `.linear` (purple), `.github` (dark green), `.clickup` (lavender), `.jira` (blue), `.asana` (red), `.notion` (dark)

```swift
TaskCard(
    source: .linear,
    id: "CLI-42",
    title: "WebSocket reconnect drops messages",
    status: .inProgress,        // .backlog | .todo | .inProgress | .done | .cancelled
    priority: .urgent,          // .urgent | .high | .medium | .low | .none
    assignee: "Egor",           // optional
    labels: ["bug", "p0"],      // optional, colored by hash
    project: "CLiOS"            // optional, shown in header
)
```

Layout:
- Header bar: source icon + source name + "· project" + task ID (JetBrains Mono)
- Status icon (large, colored) + title + priority signal bars (right-aligned, bottom-aligned steps)
- Meta line: assignee + colored label pills (tinted background per label)

Status icons: ⊙ backlog, ○ todo, ◑ in progress, ✓ done, ✕ cancelled

Priority signal bars: 4 ascending bars, filled count matches priority level. Aligned at bottom like cell signal.

Labels: colored text on 15% tinted background, color stable per label name (hash-based, no yellow).

## Generic constructor: ServiceCardView

For any service without a dedicated card. All body parameters are optional — use only what you need.

### Minimal

```swift
ServiceCardView(
    headerColor: Color(hex: "0A66C2"),
    headerIcon: "bubble.left.fill",
    headerTitle: "Slack",
    title: "3 unread mentions in #engineering"
)
```

### Full-featured

```swift
ServiceCardView(
    headerColor: Color(hex: "362D59"),
    headerIcon: "exclamationmark.triangle.fill",
    headerTitle: "Sentry",
    headerSubtitle: "· Production",
    title: "TypeError: Cannot read property 'id'",
    subtitle: "GatewayService.swift:142",
    badges: [
        CardBadge(label: "Critical", color: Theme.error, icon: "flame.fill"),
        CardBadge(label: "x12", color: Theme.warning)
    ],
    meta: [
        CardMeta(label: "First seen:", value: "2h ago", icon: "clock"),
        CardMeta(label: "Users:", value: "8", icon: "person.2")
    ]
)
```

### With markdown body

```swift
ServiceCardView(
    headerColor: Color(hex: "635BFF"),
    headerIcon: "creditcard.fill",
    headerTitle: "Stripe",
    title: "Monthly summary",
    markdown: "**MRR:** `$18,400` (up 32%)\n- *Acme Corp* upgraded to Enterprise",
    showDivider: true
)
```

### With custom content and footer slots

```swift
ServiceCardView(
    headerColor: Color(hex: "1A1A1A"),
    headerIcon: "bolt.fill",
    headerTitle: "Vercel"
) {
    Text("2m ago")          // headerTrailing slot
} content: {
    // any SwiftUI view
    Text("Deploy succeeded")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(Theme.textPrimary)
} footer: {
    Text("Triggered by push to main")
        .font(.system(size: 12))
        .foregroundColor(Theme.textMuted)
}
```

### All parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `headerColor` | `Color` | yes | Header bar color |
| `headerIcon` | `String` | yes | SF Symbol name (or asset name with `headerIconIsAsset: true`) |
| `headerTitle` | `String` | yes | Service name |
| `headerIconIsAsset` | `Bool` | no | Use image asset instead of SF Symbol |
| `headerSubtitle` | `String?` | no | Extra text in header (e.g. "· Payments") |
| `headerTrailing` | `View` | no | Right side of header |
| `title` | `String?` | no | Card title (15pt semibold) |
| `subtitle` | `String?` | no | Below title (13pt secondary) |
| `badges` | `[CardBadge]` | no | Colored capsule badges |
| `meta` | `[CardMeta]` | no | Icon + label + value rows |
| `markdown` | `String?` | no | Markdown-rendered text body |
| `showDivider` | `Bool` | no | Divider before markdown |
| `content` | `View` | no | Custom content slot |
| `footer` | `View` | no | Custom footer slot |

### CardBadge

```swift
CardBadge(label: "Passed", color: Theme.success, icon: "checkmark.circle.fill")
```

### CardMeta

```swift
CardMeta(label: "CPU:", value: "23%", icon: "cpu")
```

## Design system

All cards follow the same typography scale:

| Level | Size | Weight | Usage |
|-------|------|--------|-------|
| Header | 13 | medium | Header bar text |
| Title | 15-17 | semibold | Card title |
| Body | 14 | regular | Email/markdown body |
| Caption | 12 | regular | Meta lines, secondary info |
| Badge | 11 | medium | Status badges, labels |
| Mono | 11-12 | medium | Diff stats, task IDs (JetBrains Mono) |

All cards use Theme colors (adaptive light/dark) and share the same structure: colored header bar + white/dark body + optional footer.

## Assets

- `github` — GitHub Invertocat logo (SVG, template image)
- `git-branch` — Git branch icon from Octicons (SVG, template image)

## Dev preview

Settings > Developer > Card Catalog — shows all cards with mock data, both light and dark themes.
