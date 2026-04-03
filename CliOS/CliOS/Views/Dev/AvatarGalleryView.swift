import SwiftUI

/// Dev-only gallery showing BeamAvatar variations for different names and palettes.
struct AvatarGalleryView: View {
    private let agentNames = [
        "deploy-bot", "code-reviewer", "debugger-x", "report-agent",
        "api-architect", "morning-bot", "test-runner", "monitor-v2",
        "data-sync", "log-analyzer", "cron-scheduler", "security-scan",
        "infra-watcher", "perf-tuner", "doc-writer", "release-manager",
        "incident-bot", "onboarding-ai", "billing-agent", "search-index",
        "cache-warmer", "queue-worker", "email-drafter", "slack-notifier",
    ]

    private let alternativePalettes: [(name: String, colors: [Color])] = [
        ("Default", BeamAvatar.defaultPalette),
        ("Ocean", [
            Color(hex: "0077B6"), Color(hex: "00B4D8"), Color(hex: "90E0EF"),
            Color(hex: "CAF0F8"), Color(hex: "023E8A"),
        ]),
        ("Sunset", [
            Color(hex: "FF6B6B"), Color(hex: "FFA06B"), Color(hex: "FFD93D"),
            Color(hex: "6BCB77"), Color(hex: "4D96FF"),
        ]),
        ("Neon", [
            Color(hex: "FF00FF"), Color(hex: "00FFFF"), Color(hex: "FFFF00"),
            Color(hex: "FF3366"), Color(hex: "33FF99"),
        ]),
        ("Earth", [
            Color(hex: "8B5E3C"), Color(hex: "D4A574"), Color(hex: "2D5016"),
            Color(hex: "C7956D"), Color(hex: "5C4033"),
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                mainGallery
                sizeComparison
                determinismTest
                similarNames
                paletteVariants
                contrastTest
                chatRowPreview
            }
            .padding()
        }
        .background(Theme.bg)
        .navigationTitle("Avatar Gallery")
    }

    // MARK: - Sections

    private var mainGallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Agent Avatars (24 unique names)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 16) {
                ForEach(agentNames, id: \.self) { name in
                    VStack(spacing: 6) {
                        BeamAvatar(name: name, size: 56)
                        Text(name)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var sizeComparison: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Size Scaling")
            HStack(spacing: 20) {
                ForEach([24, 32, 40, 48, 56, 64] as [CGFloat], id: \.self) { s in
                    VStack(spacing: 4) {
                        BeamAvatar(name: "scale-test", size: s)
                        Text("\(Int(s))pt")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
    }

    private var determinismTest: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Determinism (same input = same output)")
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    BeamAvatar(name: "consistent-agent", size: 48)
                }
                Spacer()
            }
        }
    }

    private var similarNames: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Similar Names Differentiation")
            HStack(spacing: 12) {
                ForEach(["agent-1", "agent-2", "agent-3", "agent-4", "agent-5"], id: \.self) { name in
                    VStack(spacing: 4) {
                        BeamAvatar(name: name, size: 48)
                        Text(name)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
    }

    private var paletteVariants: some View {
        ForEach(alternativePalettes, id: \.name) { palette in
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Palette: \(palette.name)")
                HStack(spacing: 12) {
                    ForEach(["alpha", "bravo", "charlie", "delta", "echo", "foxtrot"], id: \.self) { name in
                        BeamAvatar(name: name, size: 48, palette: palette.colors)
                    }
                }
            }
        }
    }

    private var contrastTest: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Contrast (face color auto-switches black/white)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 12) {
                ForEach(["light-bg-test", "dark-bg-test", "mid-tone-1", "mid-tone-2",
                         "bright-yellow", "deep-purple", "neon-green", "soft-pink"], id: \.self) { name in
                    VStack(spacing: 4) {
                        BeamAvatar(name: name, size: 56)
                        Text(name)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var chatRowPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("In Context (Chat List Row)")
            VStack(spacing: 0) {
                ForEach(["deploy-bot", "code-reviewer", "debugger-x"], id: \.self) { agent in
                    HStack(spacing: 12) {
                        BeamAvatar(name: agent, size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chat with \(agent)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Text("Latest message preview goes here...")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Theme.surface)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(Theme.textMuted)
            .textCase(.uppercase)
    }
}

#Preview {
    NavigationStack {
        AvatarGalleryView()
    }
}
