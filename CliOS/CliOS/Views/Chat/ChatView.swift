import SwiftUI

struct ChatView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var inputText = ""
    @State private var isRecording = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.paddingS) {
                            ForEach(gateway.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, Theme.paddingM)
                        .padding(.top, Theme.paddingS)
                    }
                    .onChange(of: gateway.messages.count) { _, _ in
                        if let last = gateway.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                
                // Input bar
                ChatInputBar(
                    text: $inputText,
                    isRecording: $isRecording,
                    onSend: sendMessage,
                    onVoice: toggleVoice
                )
            }
            .background(Theme.bg)
            .navigationTitle(gateway.status.agentName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        gateway.sendMessage(text)
        inputText = ""
    }
    
    private func toggleVoice() {
        // TODO: Speech-to-text
        isRecording.toggle()
    }
}
