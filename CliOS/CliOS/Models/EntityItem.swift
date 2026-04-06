import Foundation
import SwiftUI

// MARK: - Entity Types

enum EntityType: String, Codable, CaseIterable {
    case file
    case task
    case session
    case agent
    case cron
    case branch

    var label: String {
        switch self {
        case .file:    return "Files"
        case .task:    return "Tasks"
        case .session: return "Sessions"
        case .agent:   return "Agents"
        case .cron:    return "Cron Jobs"
        case .branch:  return "Branches"
        }
    }

    var icon: String {
        switch self {
        case .file:    return "doc"
        case .task:    return "checklist"
        case .session: return "bubble.left"
        case .agent:   return "cpu"
        case .cron:    return "clock"
        case .branch:  return "arrow.triangle.branch"
        }
    }

    var tint: Color {
        switch self {
        case .file:    return .blue
        case .task:    return .orange
        case .session: return .purple
        case .agent:   return .green
        case .cron:    return .yellow
        case .branch:  return .cyan
        }
    }
}

// MARK: - Entity Item

/// A single searchable entity in the unified index.
struct EntityItem: Identifiable, Codable {
    let id: String              // "file:/src/App.swift", "task:42", "agent:scout"
    let type: EntityType
    let name: String            // display name
    let path: String            // full path or identifier
    let subtitle: String        // extra context (file size, task status, etc.)
    let icon: String            // SF Symbol name
    let updatedAt: Int64        // ms timestamp — when entity itself changed
    var indexedAt: Int64        // ms timestamp — when we indexed it
    var usageCount: Int         // how many times user interacted with this entity
    var lastUsedAt: Int64       // ms timestamp — last interaction

    /// Relevance score for ranking (higher = more relevant).
    /// Combines usage frequency with recency.
    var relevanceScore: Double {
        let now = Double(Int64(Date().timeIntervalSince1970 * 1000))
        let hoursSinceUsed = max(1, (now - Double(lastUsedAt)) / 3_600_000)
        let frequency = Double(usageCount)
        // Weighted: frequency matters more, recency decays logarithmically
        return (frequency * 10.0) + (100.0 / log2(hoursSinceUsed + 1))
    }

    init(
        id: String,
        type: EntityType,
        name: String,
        path: String,
        subtitle: String = "",
        icon: String? = nil,
        updatedAt: Int64 = 0,
        indexedAt: Int64 = 0,
        usageCount: Int = 0,
        lastUsedAt: Int64 = 0
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.path = path
        self.subtitle = subtitle
        self.icon = icon ?? type.icon
        self.updatedAt = updatedAt
        self.indexedAt = indexedAt
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
    }
}
