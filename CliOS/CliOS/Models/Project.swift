import Foundation

// MARK: - Project

struct Project: Codable, Identifiable {
    let id: String              // slug: "landing-v2", "crm-bot"
    var name: String            // "Landing Redesign"
    var description: String     // free-form text
    var status: ProjectStatus
    var createdAt: String       // ISO8601
    var updatedAt: String       // ISO8601
}

enum ProjectStatus: String, Codable {
    case active
    case paused
    case completed
    case archived
}

// MARK: - Project Index

struct ProjectIndex: Codable {
    var projects: [ProjectIndexEntry]
}

struct ProjectIndexEntry: Codable, Identifiable {
    let id: String              // same as Project.id
    var name: String
    var status: String          // "active", "completed", etc.
    var createdAt: String
}

// MARK: - Session Mapping

/// Maps sessionKey -> projectId.
/// Stored at workspace/projects/_sessions.json
struct SessionMapping: Codable {
    var sessions: [String: String]   // sessionKey -> projectId
}
