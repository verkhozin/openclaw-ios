import SwiftUI

struct MentionPopupView: View {
    let query: String
    let onSelect: (EntityItem) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategory: EntityType? = nil
    @State private var results: [EntityItem] = []

    private let categories: [(label: String, type: EntityType?)] = [
        ("All", nil),
        ("Files", .file),
        ("Tasks", .task),
        ("Sessions", .session),
        ("Agents", .agent),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.label) { cat in
                        Button {
                            selectedCategory = cat.type
                            updateResults()
                        } label: {
                            Text(cat.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedCategory == cat.type ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == cat.type ? Color.white : Color.white.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider().background(Color.white.opacity(0.15))

            // Results
            if results.isEmpty {
                Text(query.isEmpty ? "Recent entities" : "No results")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { entity in
                            Button { onSelect(entity) } label: {
                                MentionResultRow(entity: entity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 264)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear { updateResults() }
        .onChange(of: query) { _, _ in updateResults() }
    }

    private func updateResults() {
        let types = selectedCategory.map { [$0] }
        results = EntityIndex.shared.search(query: query, types: types, limit: 6)
    }
}

// MARK: - Popup Transition

struct MentionPopupTransition: ViewModifier {
    let blur: CGFloat
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .scaleEffect(scale, anchor: .bottom)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static var mentionPopup: AnyTransition {
        .modifier(
            active: MentionPopupTransition(blur: 10, scale: 0.92, opacity: 0),
            identity: MentionPopupTransition(blur: 0, scale: 1, opacity: 1)
        )
    }
}

// MARK: - Result Row

private struct MentionResultRow: View {
    let entity: EntityItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: entity.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(entity.type.tint)
                .frame(width: 28, height: 28)
                .background(entity.type.tint.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !entity.subtitle.isEmpty {
                    Text(entity.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
