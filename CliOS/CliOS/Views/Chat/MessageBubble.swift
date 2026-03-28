import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // TODO: Parse markdown, code blocks, service cards
                Text(message.content)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                
                if message.isStreaming {
                    ProgressView()
                        .tint(Theme.accent)
                        .scaleEffect(0.7)
                }
                
                Text(message.timestamp, style: .time)
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textMuted)
            }
            .padding(Theme.paddingM)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            
            if message.role == .agent { Spacer(minLength: 60) }
        }
    }
    
    private var bubbleBackground: Color {
        switch message.role {
        case .user: return Theme.accent.opacity(0.15)
        case .agent: return Theme.surface
        case .system: return Theme.surfaceElevated
        }
    }
}
