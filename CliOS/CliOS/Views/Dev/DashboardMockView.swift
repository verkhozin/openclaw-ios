import SwiftUI

/// Dev mock view for iterating on the new Dashboard design.
struct DashboardMockView: View {
    private let gap: CGFloat = 12

    private let cardColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1)
            : .white
    })

    private let bgColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.04, alpha: 1)
            : UIColor.systemGroupedBackground
    })

    var body: some View {
        ScrollView {
            VStack(spacing: gap) {
                // Top row: horizontal scrollable square cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: gap) {
                        squareCard("Status")
                        squareCard("Agents")
                        squareCard("Usage")
                    }
                    .padding(.horizontal, Theme.paddingM)
                }

                // Grid below
                Grid(horizontalSpacing: gap, verticalSpacing: gap) {
                    GridRow {
                        placeholder("Activity", height: 160)
                            .gridCellColumns(2)
                    }

                    GridRow {
                        placeholder("Tasks", height: 120)
                        placeholder("Crons", height: 120)
                    }

                    GridRow {
                        placeholder("Quick Actions", height: 100)
                            .gridCellColumns(2)
                    }

                    GridRow {
                        placeholder("Sessions", height: 120)
                        placeholder("Files", height: 120)
                    }

                    GridRow {
                        placeholder("Recent", height: 160)
                            .gridCellColumns(2)
                    }

                    GridRow {
                        placeholder("Logs", height: 140)
                            .gridCellColumns(2)
                    }
                }
                .padding(.horizontal, Theme.paddingM)
            }
            .padding(.top, Theme.paddingM)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Dashboard v2")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func squareCard(_ title: String) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(cardColor)
            .frame(width: 150, height: 150)
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(14)
            }
    }

    private func placeholder(_ title: String, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(cardColor)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(14)
            }
    }
}

#Preview {
    NavigationStack {
        DashboardMockView()
    }
    .preferredColorScheme(.dark)
}
