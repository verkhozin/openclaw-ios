import SwiftUI

/// Dev-only view showing all service card types with mock data.
/// Use this to design and iterate on card components.
struct CardCatalogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingL) {

                // MARK: - GitHub
                sectionHeader("GitHub")
                GitHubPRCard(
                    number: 128,
                    title: "Fix hero animation on mobile viewport",
                    status: .open,
                    author: "egor",
                    repo: "verkh-tech/site",
                    branch: "fix/hero",
                    targetBranch: "main",
                    ci: .passed,
                    additions: 42,
                    deletions: 8
                )
                GitHubPRCard(
                    number: 97,
                    title: "Refactor auth middleware to support refresh tokens",
                    status: .merged,
                    author: "alex",
                    repo: "verkh-tech/api",
                    branch: "feat/refresh-tokens",
                    targetBranch: "develop",
                    ci: .passed,
                    additions: 156,
                    deletions: 43
                )
                GitHubPRCard(
                    number: 64,
                    title: "WIP: migrate database schema to v3",
                    status: .closed,
                    author: "dima",
                    repo: "verkh-tech/core",
                    branch: "chore/db-v3",
                    targetBranch: "main",
                    ci: .failed,
                    additions: 8,
                    deletions: 220
                )
                // MARK: - Email
                sectionHeader("Email")
                EmailCard(
                    type: .inbox,
                    from: "Alex Kim <alex@partner.co>",
                    to: "egor@verkh.tech",
                    subject: "Re: Partnership proposal",
                    content: "Hey Egor,\n\nI looked at the numbers you sent over and I think we should **move forward with the deal**. The unit economics make sense, especially given the growth trajectory you showed in the deck.\n\nA few things I'd like to clarify before we sign:\n\n- What's the expected timeline for the *API integration*?\n- Do you have bandwidth on your side to support onboarding?\n- Can we get a pilot period of **30 days**?\n\nLet me know if Thursday works for a quick call.\n\nBest,\nAlex",
                    time: "10:42",
                    isUnread: true
                )
                EmailCard(
                    type: .draft,
                    from: "egor@verkh.tech",
                    to: "investor@fund.vc",
                    subject: "Q1 Update — Verkh Tech",
                    content: "Hi team,\n\nHere's our quarterly update.\n\n**Key metrics:**\n- MRR: **$18.4k** (up 32% QoQ)\n- Active users: **2,140**\n- Churn: **3.1%** (down from 4.8%)\n\nWe shipped the mobile app, closed 3 enterprise pilots, and hired a senior engineer.\n\nHappy to jump on a call if you'd like to discuss.\n\nBest,\nEgor",
                    time: "Draft"
                )
                EmailCard(
                    type: .digest,
                    from: "3 senders",
                    to: "egor@verkh.tech",
                    subject: "Morning digest — 3 new, 1 urgent",
                    content: "- **Alex Kim** — Re: Partnership proposal (*urgent*, awaiting reply)\n- **Stripe** — Invoice #4821 for `$200.00` (Claude Max)\n- **Linear Weekly** — 12 issues closed, 3 new bugs filed",
                    time: "08:00",
                    count: 3
                )

                // MARK: - Calendar
                sectionHeader("Calendar")
                cardPlaceholder(.calendarEvent, fields: [
                    "title": "Design review",
                    "time": "14:00 — 15:00",
                    "location": "Google Meet",
                    "attendees": "Egor, Alex, Dima"
                ])
                cardPlaceholder(.calendarConflict, fields: [
                    "event1": "Design review @ 14:00",
                    "event2": "Investor call @ 14:30",
                    "overlap": "30 min"
                ])

                // MARK: - Linear
                sectionHeader("Linear")
                cardPlaceholder(.linearIssue, fields: [
                    "id": "CLI-42",
                    "title": "WebSocket reconnect drops messages",
                    "status": "In Progress",
                    "priority": "Urgent"
                ])

                // MARK: - Files & Code
                sectionHeader("Files & Code")
                cardPlaceholder(.fileDiff, fields: [
                    "file": "GatewayService.swift",
                    "additions": "12",
                    "deletions": "3",
                    "summary": "Add reconnect backoff logic"
                ])
                cardPlaceholder(.filePreview, fields: [
                    "filename": "landing-v2.html",
                    "path": "workspace/landing-v2.html",
                    "size": "24 KB"
                ])

                // MARK: - Lead Pipeline
                sectionHeader("Lead Pipeline")
                cardPlaceholder(.lead, fields: [
                    "name": "Acme Corp",
                    "round": "Series A",
                    "status": "Meeting scheduled",
                    "next": "Send deck by Friday"
                ])

                // MARK: - Unknown / Fallback
                sectionHeader("Unknown (fallback)")
                cardPlaceholder(.unknown, fields: [
                    "raw": "Some unrecognized card type content that should render as formatted text"
                ])
            }
            .padding(Theme.paddingM)
        }
        .background(Theme.bg)
        .navigationTitle("Card Catalog")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.fontTitle)
            .foregroundColor(Theme.textPrimary)
            .padding(.top, Theme.paddingS)
    }

    /// Placeholder card — replace each with a real card component as you design them.
    private func cardPlaceholder(_ type: ServiceCard.CardType, fields: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.paddingS) {
            // Type badge
            Text(type.rawValue)
                .font(Theme.fontMonoSmall)
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Fields
            ForEach(fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(alignment: .top, spacing: Theme.paddingS) {
                    Text(key)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 70, alignment: .trailing)
                    Text(value)
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding(Theme.paddingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        CardCatalogView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack {
        CardCatalogView()
    }
    .preferredColorScheme(.light)
}
