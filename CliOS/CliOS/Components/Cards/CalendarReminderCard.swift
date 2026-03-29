import SwiftUI

enum ReminderPriority: String {
    case high, medium, low

    var label: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .high: Theme.error
        case .medium: Theme.warning
        case .low: Theme.textSecondary
        }
    }

    var icon: String {
        switch self {
        case .high: "exclamationmark.circle.fill"
        case .medium: "bell.fill"
        case .low: "bell"
        }
    }
}

struct CalendarReminderCard: View {
    let title: String
    let time: String
    let date: String
    let priority: ReminderPriority
    let notes: String
    let calendar: String

    // Typography: 3 levels only
    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let titleFont: Font = .system(size: 15, weight: .semibold)
    private let captionFont: Font = .system(size: 12, weight: .regular)
    private let badgeFont: Font = .system(size: 11, weight: .medium)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: calendar icon + type ... time
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                Text("Reminder")
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text(time)
                    .foregroundColor(priority.color)
                    .fontWeight(.medium)
            }
            .font(headerFont)

            // Title
            Text(title)
                .font(titleFont)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)

            // Notes (if any)
            if !notes.isEmpty {
                Text(notes)
                    .font(captionFont)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }

            // Footer: priority badge ... date · calendar
            HStack(spacing: 6) {
                badge(priority.label, icon: priority.icon, color: priority.color)

                Spacer()

                HStack(spacing: 3) {
                    Text(date)
                    Text("·").fontWeight(.bold)
                    Text(calendar)
                }
                .font(captionFont)
                .foregroundColor(Theme.textMuted)
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

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
        }
        .font(badgeFont)
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview("Dark") {
    VStack(spacing: 16) {
        CalendarReminderCard(
            title: "Reschedule sync with Gleb",
            time: "15:00",
            date: "Friday, Mar 28",
            priority: .high,
            notes: "Moved from Thursday. Confirm agenda before call.",
            calendar: "Work"
        )
        CalendarReminderCard(
            title: "Send invoice to Riva Data",
            time: "10:00",
            date: "Monday, Mar 31",
            priority: .medium,
            notes: "Q1 consulting — 3 deliverables",
            calendar: "Business"
        )
        CalendarReminderCard(
            title: "Renew domain verkh.tech",
            time: "All day",
            date: "Apr 5",
            priority: .low,
            notes: "",
            calendar: "Personal"
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    VStack(spacing: 16) {
        CalendarReminderCard(
            title: "Reschedule sync with Gleb",
            time: "15:00",
            date: "Friday, Mar 28",
            priority: .high,
            notes: "Moved from Thursday. Confirm agenda before call.",
            calendar: "Work"
        )
        CalendarReminderCard(
            title: "Send invoice to Riva Data",
            time: "10:00",
            date: "Monday, Mar 31",
            priority: .medium,
            notes: "",
            calendar: "Business"
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
