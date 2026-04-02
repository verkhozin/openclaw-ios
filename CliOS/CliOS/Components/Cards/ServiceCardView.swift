import SwiftUI

/// Generic card constructor with built-in elements for common patterns.
/// All body elements are optional — use only what you need.
struct ServiceCardView<HeaderTrailing: View, Content: View, Footer: View>: View {

    // MARK: - Header
    let headerColor: Color
    let headerIcon: String
    let headerIconIsAsset: Bool
    let headerTitle: String
    let headerSubtitle: String?
    @ViewBuilder let headerTrailing: HeaderTrailing

    // MARK: - Built-in body elements (all optional)
    let title: String?
    let subtitle: String?
    let markdown: String?
    let badges: [CardBadge]
    let meta: [CardMeta]
    let checklist: [ChecklistItem]
    let showDivider: Bool

    // MARK: - Custom slots
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    // MARK: - Typography
    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let titleFont: Font = .system(size: 15, weight: .semibold)
    private let subtitleFont: Font = .system(size: 13, weight: .regular)
    private let captionFont: Font = .system(size: 12, weight: .regular)
    private let badgeFont: Font = .system(size: 11, weight: .medium)
    private let bodyFont: Font = .system(size: 14, weight: .regular)

    init(
        headerColor: Color,
        headerIcon: String,
        headerTitle: String,
        headerIconIsAsset: Bool = false,
        headerSubtitle: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        markdown: String? = nil,
        badges: [CardBadge] = [],
        meta: [CardMeta] = [],
        checklist: [ChecklistItem] = [],
        showDivider: Bool = false,
        @ViewBuilder headerTrailing: () -> HeaderTrailing = { EmptyView() },
        @ViewBuilder content: () -> Content = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.headerColor = headerColor
        self.headerIcon = headerIcon
        self.headerIconIsAsset = headerIconIsAsset
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.title = title
        self.subtitle = subtitle
        self.markdown = markdown
        self.badges = badges
        self.meta = meta
        self.checklist = checklist
        self.showDivider = showDivider
        self.headerTrailing = headerTrailing()
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(alignment: .center, spacing: 5) {
                if headerIconIsAsset {
                    Image(headerIcon)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: headerIcon)
                        .font(.system(size: 12))
                }

                Text(headerTitle)

                if let headerSubtitle {
                    Text(headerSubtitle)
                        .opacity(0.7)
                }

                Spacer()

                headerTrailing
                    .opacity(0.7)
            }
            .font(headerFont)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(headerColor)

            // Body
            VStack(alignment: .leading, spacing: 8) {
                // Title
                if let title {
                    Text(title)
                        .font(titleFont)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                }

                // Subtitle
                if let subtitle {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundColor(Theme.textSecondary)
                }

                // Badges row
                if !badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badges) { badge in
                            badgeView(badge)
                        }
                    }
                }

                // Meta rows
                if !meta.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(meta) { item in
                            metaRow(item)
                        }
                    }
                }

                // Checklist
                if !checklist.isEmpty {
                    CardChecklist(items: checklist)
                }

                // Divider
                if showDivider {
                    Divider().background(Theme.border)
                }

                // Markdown body
                if let markdown {
                    markdownView(markdown)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Custom content slot
                if Content.self != EmptyView.self {
                    content
                }

                // Footer slot
                if Footer.self != EmptyView.self {
                    footer
                }
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

    // MARK: - Subviews

    private func badgeView(_ badge: CardBadge) -> some View {
        HStack(spacing: 3) {
            if let icon = badge.icon {
                Image(systemName: icon)
            }
            Text(badge.label)
        }
        .font(badgeFont)
        .foregroundColor(badge.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(badge.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func metaRow(_ item: CardMeta) -> some View {
        HStack(spacing: 4) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }
            Text(item.label)
                .foregroundColor(Theme.textMuted)
            if let value = item.value {
                Text(value)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .font(captionFont)
    }

    private func markdownView(_ text: String) -> some View {
        let spans = MessageParser.parseInlineMarkdown(text)
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
            }
        }
        .lineSpacing(4)
    }
}

// MARK: - Data models

struct CardBadge: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
    var icon: String? = nil
}

struct CardMeta: Identifiable {
    let id = UUID()
    let label: String
    var value: String? = nil
    var icon: String? = nil
}

// MARK: - Previews

#Preview("Dark") {
    ScrollView {
        VStack(spacing: 16) {
            // Full-featured: Vercel deploy
            ServiceCardView(
                headerColor: Color(hex: "1A1A1A"),
                headerIcon: "bolt.fill",
                headerTitle: "Vercel",
                title: "Deploy succeeded",
                badges: [
                    CardBadge(label: "Production", color: Theme.success, icon: "checkmark.circle.fill"),
                    CardBadge(label: "48s", color: Theme.textSecondary, icon: "clock")
                ],
                meta: [
                    CardMeta(label: "URL:", value: "verkh.tech", icon: "link"),
                    CardMeta(label: "Branch:", value: "main", icon: "arrow.triangle.branch")
                ]
            ) {
                Text("2m ago")
            } footer: {
                HStack(spacing: 3) {
                    Text("Triggered by push to main")
                }
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
            }

            // Stripe with markdown
            ServiceCardView(
                headerColor: Color(hex: "635BFF"),
                headerIcon: "creditcard.fill",
                headerTitle: "Stripe",
                headerSubtitle: "· Payments",
                title: "Monthly summary",
                markdown: "**MRR:** `$18,400` (up 32%)\n**New customers:** 14\n**Churn:** 2 accounts\n\n- *Acme Corp* upgraded to Enterprise\n- Pending invoice for **$3,200**",
                showDivider: true
            )

            // Sentry with badges
            ServiceCardView(
                headerColor: Color(hex: "362D59"),
                headerIcon: "exclamationmark.triangle.fill",
                headerTitle: "Sentry",
                title: "TypeError: Cannot read property 'id' of undefined",
                subtitle: "GatewayService.swift:142 → handleMessage()",
                badges: [
                    CardBadge(label: "Critical", color: Theme.error, icon: "flame.fill"),
                    CardBadge(label: "×12 events", color: Theme.warning, icon: "arrow.up.right")
                ],
                meta: [
                    CardMeta(label: "First seen:", value: "2h ago", icon: "clock"),
                    CardMeta(label: "Users affected:", value: "8", icon: "person.2")
                ]
            )

            // Minimal: Slack
            ServiceCardView(
                headerColor: Color(hex: "0A66C2"),
                headerIcon: "bubble.left.fill",
                headerTitle: "Slack",
                headerSubtitle: "· #engineering",
                title: "3 unread mentions",
                badges: [
                    CardBadge(label: "Urgent", color: Theme.error)
                ]
            )

            // Meta-only: Server health
            ServiceCardView(
                headerColor: Color(hex: "2D9CDB"),
                headerIcon: "server.rack",
                headerTitle: "Server",
                headerSubtitle: "· gateway-01",
                meta: [
                    CardMeta(label: "CPU:", value: "23%", icon: "cpu"),
                    CardMeta(label: "RAM:", value: "1.2 / 4 GB", icon: "memorychip"),
                    CardMeta(label: "Uptime:", value: "14d 6h", icon: "clock.arrow.circlepath"),
                    CardMeta(label: "Status:", value: "Healthy", icon: "checkmark.shield")
                ]
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
            ServiceCardView(
                headerColor: Color(hex: "635BFF"),
                headerIcon: "creditcard.fill",
                headerTitle: "Stripe",
                title: "Payment received — $2,400.00",
                badges: [
                    CardBadge(label: "Succeeded", color: Theme.success, icon: "checkmark.circle.fill")
                ],
                meta: [
                    CardMeta(label: "From:", value: "Acme Corp", icon: "person.circle"),
                    CardMeta(label: "Invoice:", value: "#4821", icon: "doc.text")
                ]
            )

            ServiceCardView(
                headerColor: Color(hex: "2D9CDB"),
                headerIcon: "server.rack",
                headerTitle: "Server",
                headerSubtitle: "· gateway-01",
                meta: [
                    CardMeta(label: "CPU:", value: "23%", icon: "cpu"),
                    CardMeta(label: "RAM:", value: "1.2 / 4 GB", icon: "memorychip")
                ]
            )
        }
        .padding()
    }
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
