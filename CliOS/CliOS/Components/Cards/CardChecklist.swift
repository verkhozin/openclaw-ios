import SwiftUI

struct ChecklistItem: Identifiable {
    let id = UUID()
    let text: String
    var isCompleted: Bool
    var assignee: String? = nil
}

struct CardChecklist: View {
    let items: [ChecklistItem]

    private let textFont: Font = .system(size: 14, weight: .regular)
    private let captionFont: Font = .system(size: 11, weight: .regular)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: ChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.isCompleted ? Theme.textPrimary : Color.clear)
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(item.isCompleted ? Theme.textPrimary : Theme.border, lineWidth: 1.5)
                    )

                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.surface)
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(textFont)
                    .foregroundColor(item.isCompleted ? Theme.textMuted : Theme.textPrimary)
                    .strikethrough(item.isCompleted, color: Theme.textMuted)

                if let assignee = item.assignee {
                    Text(assignee)
                        .font(captionFont)
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview("Dark") {
    CardChecklist(items: [
        ChecklistItem(text: "Design card components", isCompleted: true, assignee: "Egor"),
        ChecklistItem(text: "Implement WebSocket reconnect", isCompleted: true),
        ChecklistItem(text: "Add markdown rendering", isCompleted: true),
        ChecklistItem(text: "Write tests for CardParser", isCompleted: false, assignee: "Alex"),
        ChecklistItem(text: "Set up CI pipeline", isCompleted: false),
    ])
    .padding(Theme.paddingM)
    .background(Theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    .overlay(
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .stroke(Theme.border, lineWidth: 1)
    )
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    CardChecklist(items: [
        ChecklistItem(text: "Design card components", isCompleted: true),
        ChecklistItem(text: "Write tests", isCompleted: false),
        ChecklistItem(text: "Deploy to production", isCompleted: false),
    ])
    .padding(Theme.paddingM)
    .background(Theme.surface)
    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    .overlay(
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .stroke(Theme.border, lineWidth: 1)
    )
    .padding()
    .background(Theme.bg)
    .preferredColorScheme(.light)
}
