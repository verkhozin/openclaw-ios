import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var gateway: GatewayService
    @Environment(\.colorScheme) private var colorScheme
    @State private var paletteIndex = 0
    @State private var isRefreshing = false
    @State private var navigateToChat = false
    @State private var knownSessionKeys: Set<String> = []
    @State private var isOnScreen = false
    @State private var entranceAppeared = false

    private static let palettes: [(blobs: [Color], highlights: [Color])] = [
        // Deep ocean + teal spark
        (
            blobs: [Color(hex: "1A3A5C"), Color(hex: "2D6A4F"), Color(hex: "264653")],
            highlights: [Color(hex: "3A8F85").opacity(0.5), Color(hex: "2196F3").opacity(0.3)]
        ),
        // Indigo + warm amber
        (
            blobs: [Color(hex: "4A3B8F"), Color(hex: "8B5A2B"), Color(hex: "5C3D6E")],
            highlights: [Color(hex: "D4915C").opacity(0.4), Color(hex: "7B68AE").opacity(0.4)]
        ),
        // Plum + forest
        (
            blobs: [Color(hex: "5B2C6F"), Color(hex: "1E5631"), Color(hex: "3B3078")],
            highlights: [Color(hex: "48A97E").opacity(0.4), Color(hex: "9B59B6").opacity(0.3)]
        ),
        // Slate blue + rose
        (
            blobs: [Color(hex: "2C3E6B"), Color(hex: "7B3B5E"), Color(hex: "1F4E5F")],
            highlights: [Color(hex: "C06C84").opacity(0.4), Color(hex: "4A6FA5").opacity(0.3)]
        ),
    ]

    private var currentPalette: (blobs: [Color], highlights: [Color]) {
        Self.palettes[paletteIndex % Self.palettes.count]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed: gradient + header
                sessionsHeader

                // Fixed: white card with scrollable content inside
                VStack(spacing: 0) {
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            chatRows
                                .padding(.top, 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Theme.bg, Theme.bg.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    .allowsHitTesting(false)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                )
            }
            .background {
                ZStack {
                    Color(hex: "1A1A2E")
                    FluidGradient(
                        blobs: currentPalette.blobs,
                        highlights: currentPalette.highlights,
                        speed: 0.25,
                        blur: 0.85
                    )
                }
                .ignoresSafeArea()
                .onAppear { startPaletteRotation() }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToChat) {
                ChatScreenView()
                    .navigationBarHidden(true)
                    .toolbar(.hidden, for: .tabBar)
            }
            .onAppear {
                isOnScreen = true
                knownSessionKeys = Set(sessions.map(\.sessionKey))
                if !entranceAppeared {
                    withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                        entranceAppeared = true
                    }
                }
            }
            .onDisappear {
                isOnScreen = false
            }
            .onChange(of: sessions.map(\.sessionKey)) { old, new in
                // When off-screen, silently accept new sessions
                if !isOnScreen {
                    knownSessionKeys = Set(new)
                }
            }
        }
    }

    private func isNewSession(_ key: String) -> Bool {
        isOnScreen && !knownSessionKeys.contains(key)
    }

    // MARK: - Hero Header Card

    private var sessionsHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isRefreshing {
                HStack {
                    Spacer()
                    TypingDotsLoader(color: .white)
                    Spacer()
                }
                .padding(.bottom, 10)
                .transition(.opacity)
            }

            Text("Sessions")
                .font(.system(size: 36, weight: .heavy))
                .foregroundColor(.white)
                .padding(.top, 8)
                .padding(.horizontal, 20)
                .opacity(entranceAppeared ? 1 : 0)
                .offset(y: entranceAppeared ? 0 : 20)

            pinnedAgentsRow
                .padding(.top, 14)
                .opacity(entranceAppeared ? 1 : 0)
                .offset(y: entranceAppeared ? 0 : 15)
        }
        .padding(.bottom, 12)
        .frame(height: isRefreshing ? 194 : 164)
        .animation(.easeInOut(duration: 0.35), value: isRefreshing)
    }

    // MARK: - Pinned Agents + Shortcuts

    private struct AgentShortcut: Identifiable {
        let id = UUID()
        let agentId: String
        let label: String
        let needsReply: Bool
    }

    private var mockShortcuts: [AgentShortcut] {
        [
            AgentShortcut(agentId: "deploy-bot", label: "Deploy failed", needsReply: true),
            AgentShortcut(agentId: "code-reviewer", label: "Approve PR?", needsReply: true),
            AgentShortcut(agentId: "monitor", label: "All healthy", needsReply: false),
            AgentShortcut(agentId: "test-runner", label: "Coverage 78%", needsReply: false),
            AgentShortcut(agentId: "api-bot", label: "Pick strategy", needsReply: true),
        ]
    }

    private var pinnedAgentsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Add button
                Button {
                    startNewChat()
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        Text("Add")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Pinned first, then needs-reply
                ForEach(mockShortcuts.sorted { !$0.needsReply && $1.needsReply }) { shortcut in
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            BeamAvatar(name: shortcut.agentId, size: 52)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            shortcut.needsReply
                                                ? Color.orange.opacity(0.8)
                                                : Color.white.opacity(0.3),
                                            lineWidth: shortcut.needsReply ? 2 : 1.5
                                        )
                                )

                            if shortcut.needsReply {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle().stroke(Color(hex: "1A1A2E"), lineWidth: 2)
                                    )
                                    .offset(x: 1, y: -1)
                            } else {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(3)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                                    .offset(x: 2, y: -2)
                            }
                        }

                        Text(shortcut.label)
                            .font(.system(size: 11, weight: shortcut.needsReply ? .semibold : .regular))
                            .foregroundColor(shortcut.needsReply ? .white : .white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(width: 58)
                }

                // Plain agent circles (no shortcut)
                ForEach(pinnedAgents, id: \.self) { agentId in
                    VStack(spacing: 6) {
                        BeamAvatar(name: agentId, size: 52)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                        Text(agentDisplayName(agentId))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(width: 58)
                }
            }
            .padding(.horizontal, 20)
            .scrollTargetLayout()
        }
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
                Color.white
                LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 16)
            }
        )
    }

    // MARK: - Chat Rows

    @State private var sessionToDelete: ChatSession?

    private var chatRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                let isNew = isNewSession(session.sessionKey)

                NavigationLink {
                    ChatScreenView()
                        .navigationBarHidden(true)
                        .toolbar(.hidden, for: .tabBar)
                        .onAppear {
                            gateway.sessionStore.openSession(key: session.sessionKey)
                        }
                } label: {
                    ChatSessionRow(session: session)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            sessionToDelete = session
                        }
                )
                .offset(y: isNew ? 30 : (entranceAppeared ? 0 : 25))
                .opacity(isNew ? 0 : (entranceAppeared ? 1 : 0))
                .scaleEffect(isNew ? 0.95 : 1, anchor: .top)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.06),
                    value: entranceAppeared
                )
                .onAppear {
                    guard isNew else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        knownSessionKeys.insert(session.sessionKey)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .confirmationDialog(
            "Delete session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateway.sessionStore.deleteSession(key: session.sessionKey)
                    }
                }
                sessionToDelete = nil
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Theme.textMuted)
            Text("No conversations yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Text("Start a new chat with your agent")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
            Button {
                startNewChat()
            } label: {
                Text("New Chat")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer().frame(height: 60)
        }
    }

    // MARK: - Data

    private var sessions: [ChatSession] {
        let real = gateway.sessionStore.sessions
        #if DEBUG
        if real.isEmpty { return Self.mockSessions }
        #endif
        return real.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    private var pinnedAgents: [String] {
        // Unique agent IDs from recent sessions
        var seen = Set<String>()
        return sessions.compactMap { session in
            let id = session.agentId
            guard !id.isEmpty, seen.insert(id).inserted else { return nil }
            return id
        }
    }

    private func agentDisplayName(_ id: String) -> String {
        // Show first part of agent ID, capitalized
        let name = id.split(separator: "-").first.map(String.init) ?? id
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    #if DEBUG
    private static let mockSessions: [ChatSession] = {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return [
            ChatSession(
                sessionKey: "mock-1",
                title: "Deploy to production",
                lastMessageAt: now - 120_000,
                lastMessagePreview: "Done. All 3 services deployed, health checks passing. Want me to monitor for the next 30 min?",
                unreadCount: 2,
                agentId: "deploy-bot",
                model: "claude-sonnet",
                cachedUntilSeq: 42
            ),
            ChatSession(
                sessionKey: "mock-2",
                title: "Refactor auth middleware",
                lastMessageAt: now - 3_600_000,
                lastMessagePreview: "I've extracted the token validation into a shared module. PR #47 is ready for review.",
                unreadCount: 0,
                agentId: "code-reviewer",
                model: "claude-sonnet",
                cachedUntilSeq: 28
            ),
            ChatSession(
                sessionKey: "mock-3",
                title: "Debug memory leak",
                lastMessageAt: now - 14_400_000,
                lastMessagePreview: "Found it — the WebSocket listener wasn't being deallocated. Fix pushed.",
                unreadCount: 0,
                agentId: "debugger-x",
                model: "claude-opus",
                cachedUntilSeq: 15
            ),
            ChatSession(
                sessionKey: "mock-4",
                title: "Weekly report",
                lastMessageAt: now - 86_400_000,
                lastMessagePreview: "Here's the summary: 12 PRs merged, 3 incidents resolved, test coverage up to 78%.",
                unreadCount: 5,
                agentId: "report-agent",
                model: "claude-sonnet",
                cachedUntilSeq: 8
            ),
            ChatSession(
                sessionKey: "mock-5",
                title: "API rate limiting",
                lastMessageAt: now - 259_200_000,
                lastMessagePreview: "Implemented sliding window rate limiter at 100 req/min per user. Tests green.",
                unreadCount: 0,
                agentId: "api-architect",
                model: "claude-haiku",
                cachedUntilSeq: 33
            ),
            ChatSession(
                sessionKey: "mock-6",
                title: "Morning briefing",
                lastMessageAt: now - 604_800_000,
                lastMessagePreview: "Good morning! You have 2 PRs to review, 1 failing CI job, and a meeting at 2pm.",
                unreadCount: 0,
                agentId: "morning-bot",
                model: "claude-sonnet",
                cachedUntilSeq: 5
            ),
        ]
    }()
    #endif

    private func triggerRefresh() {
        guard !isRefreshing else { return }
        withAnimation { isRefreshing = true }
        Task {
            // TODO: Trigger actual session refresh from gateway
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isRefreshing = false }
        }
    }

    private func startPaletteRotation() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 8)) {
                paletteIndex += 1
            }
        }
    }

    private func startNewChat() {
        let key = UUID().uuidString
        gateway.sessionStore.ensureSession(key: key)
        gateway.sessionStore.openSession(key: key)
        navigateToChat = true
    }

    private func deleteSession(at offsets: IndexSet) {
        // TODO: Implement session deletion in SessionStore
    }
}

// MARK: - Session Row

struct ChatSessionRow: View {
    let session: ChatSession

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                BeamAvatar(name: session.agentId.isEmpty ? session.sessionKey : session.agentId, size: 48)
                Circle()
                    .fill(Theme.success)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(Theme.bg, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title.isEmpty ? "New Chat" : session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(timeAgo(ms: session.lastMessageAt))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                }

                HStack {
                    Text(session.lastMessagePreview.isEmpty ? "No messages" : session.lastMessagePreview)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    if session.unreadCount > 0 {
                        Text("\(session.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.bg)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func timeAgo(ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let diff = Date().timeIntervalSince(date)

        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        if diff < 604800 { return "\(Int(diff / 86400))d" }

        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview("With chats") {
    ChatListView()
        .environmentObject(GatewayService.shared)
}

#Preview("Empty") {
    ChatListView()
        .environmentObject(GatewayService.shared)
}

