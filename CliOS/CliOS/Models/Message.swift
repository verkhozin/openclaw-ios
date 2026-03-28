import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var serviceCard: ServiceCard?
    
    enum Role: String, Codable {
        case user
        case agent
        case system
    }
    
    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        serviceCard: ServiceCard? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.serviceCard = serviceCard
    }
}
