import SwiftUI

enum EmailType: String {
    case inbox, draft, digest

    var label: String {
        switch self {
        case .inbox: "Inbox"
        case .draft: "Draft"
        case .digest: "Digest"
        }
    }

    var icon: String {
        switch self {
        case .inbox: "envelope.fill"
        case .draft: "pencil.and.outline"
        case .digest: "tray.full.fill"
        }
    }
}

struct EmailCard: View {
    let type: EmailType
    let from: String
    let to: String
    let subject: String
    let content: String
    let time: String
    var isUnread: Bool = false
    var count: Int? = nil

    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let titleFont: Font = .system(size: 15, weight: .semibold)
    private let bodyFont: Font = .system(size: 14, weight: .regular)
    private let captionFont: Font = .system(size: 12, weight: .regular)
    private let badgeFont: Font = .system(size: 11, weight: .medium)

    private let emailBlue = Color(hex: "4285F4")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored header bar
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: type.icon)
                    .font(.system(size: 12))

                Text("Email")

                Text("· \(type.label)")
                    .opacity(0.7)

                if isUnread {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                }

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(badgeFont)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                Text(time)
                    .opacity(0.7)
            }
            .font(headerFont)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .background(emailBlue)

            // Card body
            VStack(alignment: .leading, spacing: 10) {
                // From / To
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("From:")
                            .foregroundColor(Theme.textMuted)
                        Text(from)
                            .foregroundColor(Theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Text("To:")
                            .foregroundColor(Theme.textMuted)
                        Text(to)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .font(captionFont)

                // Subject
                Text(subject)
                    .font(titleFont)
                    .foregroundColor(Theme.textPrimary)

                Divider()
                    .background(Theme.border)

                // Full body (markdown)
                markdownBody
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.paddingM)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var markdownBody: some View {
        let spans = MessageParser.parseInlineMarkdown(content)
        return spans.reduce(Text("")) { result, span in
            switch span {
            case .plain(_, let s):
                result + Text(s)
                    .font(bodyFont)
                    .foregroundColor(Theme.textPrimary)
            case .bold(_, let s):
                result + Text(s)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            case .italic(_, let s):
                result + Text(s)
                    .font(.system(size: 14, weight: .regular).italic())
                    .foregroundColor(Theme.textPrimary)
            case .inlineCode(_, let s):
                result + Text(s)
                    .font(.custom("JetBrainsMono-Regular", size: 13))
                    .foregroundColor(Theme.accent)
            case .heading(_, let level, let s):
                result + Text(s)
                    .font(.system(size: level == 1 ? 18 : level == 2 ? 16 : 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .lineSpacing(4)
    }
}

#Preview("Dark") {
    ScrollView {
        VStack(spacing: 16) {
            EmailCard(
                type: .inbox,
                from: "Alex Kim <alex@partner.co>",
                to: "egor@verkh.tech",
                subject: "Re: Partnership proposal",
                content: "Hey Egor,\n\nI looked at the numbers you sent over and I think we should **move forward with the deal**. The unit economics make sense, especially given the growth trajectory you showed in the deck.\n\nA few things I'd like to clarify before we sign:\n\n- What's the expected timeline for the *API integration*?\n- Do you have bandwidth on your side to support onboarding for our team of 12?\n- Can we get a pilot period of **30 days** before committing to the annual plan?\n\nLet me know if Thursday works for a quick call to finalize.\n\nBest,\nAlex",
                time: "10:42",
                isUnread: true
            )
            EmailCard(
                type: .draft,
                from: "egor@verkh.tech",
                to: "investor@fund.vc",
                subject: "Q1 Update — Verkh Tech",
                content: "Hi team,\n\nHere's our quarterly update.\n\n**Key metrics:**\n- MRR: **$18.4k** (up 32% QoQ)\n- Active users: **2,140**\n- Churn: **3.1%** (down from 4.8%)\n\nWe shipped the mobile app, closed 3 enterprise pilots, and hired a senior engineer. Next quarter we're focused on the `API platform` launch.\n\nHappy to jump on a call if you'd like to discuss.\n\nBest,\nEgor",
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
        }
        .padding()
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    ScrollView {
        VStack(spacing: 16) {
            EmailCard(
                type: .inbox,
                from: "Alex Kim <alex@partner.co>",
                to: "egor@verkh.tech",
                subject: "Re: Partnership proposal",
                content: "Hey Egor,\n\nI looked at the numbers you sent over and I think we should **move forward with the deal**. The unit economics make sense, especially given the growth trajectory you showed in the deck.\n\nA few things I'd like to clarify before we sign:\n\n- What's the expected timeline for the *API integration*?\n- Do you have bandwidth on your side to support onboarding for our team of 12?\n- Can we get a pilot period of **30 days** before committing to the annual plan?\n\nLet me know if Thursday works for a quick call to finalize.\n\nBest,\nAlex",
                time: "10:42",
                isUnread: true
            )
        }
        .padding()
    }
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
