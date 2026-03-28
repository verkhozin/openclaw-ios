import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var isRecording: Bool
    let onSend: () -> Void
    let onVoice: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.paddingS) {
            // Voice button
            Button(action: onVoice) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.title3)
                    .foregroundColor(isRecording ? Theme.error : Theme.textSecondary)
            }
            .frame(width: 44, height: 44)
            
            // Text field
            TextField("Message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1...5)
                .padding(.horizontal, Theme.paddingS)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(text.isEmpty ? Theme.textMuted : Theme.accent)
            }
            .frame(width: 44, height: 44)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Theme.paddingM)
        .padding(.vertical, Theme.paddingS)
        .background(Theme.bg)
    }
}
