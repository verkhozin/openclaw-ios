import Foundation
import SwiftUI

// MARK: - Calendar Event

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let source: Source
    var sourceId: String?           // ID in the source system (Google, Outlook, etc.)
    var location: String?
    var notes: String?
    var attendees: [Attendee]
    var status: Status
    var recurrence: RecurrenceRule?
    var color: String?              // hex color from source calendar

    enum Source: String, Codable {
        case google
        case apple
        case outlook
        case agent                  // agent-created
        case manual                 // user-created in CLiOS
    }

    enum Status: String, Codable {
        case confirmed
        case tentative
        case cancelled
    }

    struct Attendee: Codable, Hashable {
        let name: String
        var email: String?
        var rsvp: String?           // accepted, declined, tentative, needsAction
    }

    struct RecurrenceRule: Codable {
        let frequency: Frequency
        var interval: Int           // every N frequency units
        var until: Date?            // end date (nil = forever)
        var count: Int?             // max occurrences (nil = unlimited)
        var daysOfWeek: [Int]?      // 1=Sun..7=Sat (for weekly)

        enum Frequency: String, Codable {
            case daily, weekly, monthly, yearly
        }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        source: Source = .agent,
        sourceId: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        attendees: [Attendee] = [],
        status: Status = .confirmed,
        recurrence: RecurrenceRule? = nil,
        color: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.source = source
        self.sourceId = sourceId
        self.location = location
        self.notes = notes
        self.attendees = attendees
        self.status = status
        self.recurrence = recurrence
        self.color = color
    }
}

// MARK: - Calendar Displayable

/// Any model with a date range can appear on the calendar.
/// Conform to this to surface tasks, cron jobs, events, etc. in a unified calendar view.
protocol CalendarDisplayable {
    var calendarId: String { get }
    var calendarTitle: String { get }
    var calendarStart: Date { get }
    var calendarEnd: Date? { get }
    var calendarIsAllDay: Bool { get }
    var calendarColor: Color { get }
    var calendarIcon: String { get }
}

// MARK: - Conformances

extension CalendarEvent: CalendarDisplayable {
    var calendarId: String { id }
    var calendarTitle: String { title }
    var calendarStart: Date { startDate }
    var calendarEnd: Date? { endDate }
    var calendarIsAllDay: Bool { isAllDay }
    var calendarIcon: String { "calendar" }

    var calendarColor: Color {
        if let hex = color { return Color(hex: hex) }
        switch source {
        case .google:  return .blue
        case .apple:   return .red
        case .outlook: return .cyan
        case .agent:   return .green
        case .manual:  return .orange
        }
    }
}

extension AgentTask: CalendarDisplayable {
    var calendarId: String { "task:\(id)" }
    var calendarTitle: String { label }
    var calendarStart: Date { startedAt }
    var calendarEnd: Date? { endedAt }
    var calendarIsAllDay: Bool { false }
    var calendarColor: Color { .orange }
    var calendarIcon: String { "checklist" }
}

extension CronJob: CalendarDisplayable {
    var calendarId: String { "cron:\(id)" }
    var calendarTitle: String { name }
    var calendarStart: Date { nextRunAt ?? lastRunAt ?? Date() }
    var calendarEnd: Date? { nil }
    var calendarIsAllDay: Bool { false }
    var calendarColor: Color { .yellow }
    var calendarIcon: String { "clock" }
}

