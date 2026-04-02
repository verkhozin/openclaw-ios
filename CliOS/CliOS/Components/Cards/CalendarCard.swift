import SwiftUI

struct CalendarCard: View {
    let title: String
    let date: String
    let startTime: String
    let endTime: String
    let duration: String
    let location: String
    let attendees: [String]

    private let headerFont: Font = .system(size: 13, weight: .medium)
    private let calendarRed = Color(hex: "EA4335")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))

                Text("Calendar")

                Spacer()

                Text(date)
                    .opacity(0.7)
            }
            .font(headerFont)
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(calendarRed)

            // Two-column body: time block | details
            HStack(alignment: .top, spacing: 0) {
                // Left: time column
                VStack(spacing: 2) {
                    Text(startTime)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(Theme.textPrimary)

                    // Duration pill
                    Text(duration)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(calendarRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(calendarRed.opacity(0.12))
                        .clipShape(Capsule())

                    Text(endTime)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Theme.textMuted)
                }
                .frame(width: 80)
                .padding(.vertical, Theme.paddingM)

                // Divider line
                Rectangle()
                    .fill(calendarRed.opacity(0.3))
                    .frame(width: 2)
                    .padding(.vertical, 12)

                // Right: event details
                VStack(alignment: .leading, spacing: 10) {
                    // Title
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)

                    // Location
                    if !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 11))
                                .foregroundColor(calendarRed)

                            Text(location)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    // Attendees
                    if !attendees.isEmpty {
                        HStack(spacing: 6) {
                            // Avatar circles
                            HStack(spacing: -6) {
                                ForEach(Array(attendees.prefix(4).enumerated()), id: \.offset) { i, name in
                                    ZStack {
                                        Circle()
                                            .fill(avatarColor(i))
                                            .frame(width: 24, height: 24)
                                        Text(String(name.prefix(1)))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .overlay(
                                        Circle().stroke(Theme.surface, lineWidth: 2)
                                    )
                                }

                                if attendees.count > 4 {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.surfaceElevated)
                                            .frame(width: 24, height: 24)
                                        Text("+\(attendees.count - 4)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .overlay(
                                        Circle().stroke(Theme.surface, lineWidth: 2)
                                    )
                                }
                            }

                            Text(attendeesLabel)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Theme.textMuted)
                        }
                    }
                }
                .padding(Theme.paddingM)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var attendeesLabel: String {
        if attendees.count <= 2 {
            return attendees.joined(separator: ", ")
        }
        return "\(attendees.count) people"
    }

    private func avatarColor(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "4285F4"),
            Color(hex: "EA4335"),
            Color(hex: "FBBC04"),
            Color(hex: "34A853")
        ]
        return colors[index % colors.count]
    }
}

#Preview("Dark") {
    ScrollView {
        VStack(spacing: 16) {
            // Full: location + attendees
            CalendarCard(
                title: "Design review",
                date: "Mar 29",
                startTime: "14:00",
                endTime: "15:00",
                duration: "1h",
                location: "Google Meet",
                attendees: ["Egor", "Alex", "Dima"]
            )
            // Many attendees, no location
            CalendarCard(
                title: "Investor call — Q1 update & fundraising strategy",
                date: "Mar 31",
                startTime: "17:00",
                endTime: "17:30",
                duration: "30m",
                location: "",
                attendees: ["Egor", "Sarah", "Mike", "Anna", "Tom", "Lisa"]
            )
            // No attendees, no location
            CalendarCard(
                title: "Focus time",
                date: "Mar 30",
                startTime: "09:00",
                endTime: "12:00",
                duration: "3h",
                location: "",
                attendees: []
            )
            // No attendees, with location
            CalendarCard(
                title: "Dentist",
                date: "Apr 2",
                startTime: "11:30",
                endTime: "12:00",
                duration: "30m",
                location: "ул. Тверская, 15",
                attendees: []
            )
        }
        .padding()
    }
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    VStack(spacing: 16) {
        CalendarCard(
            title: "Design review",
            date: "Mar 29",
            startTime: "14:00",
            endTime: "15:00",
            duration: "1h",
            location: "Google Meet",
            attendees: ["Egor", "Alex", "Dima"]
        )
        CalendarCard(
            title: "Focus time",
            date: "Mar 30",
            startTime: "09:00",
            endTime: "12:00",
            duration: "3h",
            location: "",
            attendees: []
        )
    }
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
