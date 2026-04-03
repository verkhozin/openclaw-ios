import SwiftUI

/// Dev-only gallery showing FolderFrontShape variations.
struct FolderGalleryView: View {
    private let colorSets: [(name: String, color: Color)] = [
        ("Default", Color(hex: "3A3A3C")),
        ("Orange", Theme.accent),
        ("Blue", Color(hex: "007AFF")),
        ("Green", Color(hex: "34C759")),
        ("Purple", Color(hex: "AF52DE")),
        ("Red", Color(hex: "FF3B30")),
        ("Teal", Color(hex: "5AC8FA")),
        ("Dark", Color(hex: "1C1C1E")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingM) {
                Text("Colors")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, Theme.paddingM)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(colorSets, id: \.name) { set in
                        VStack(spacing: 4) {
                            FolderView(color: set.color)
                            Text(set.name)
                                .font(.system(.caption2))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, Theme.paddingM)

                Text("Sizes")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, Theme.paddingM)

                HStack(alignment: .bottom, spacing: Theme.paddingS) {
                    folderSize(w: 40)
                    folderSize(w: 70)
                    folderSize(w: 100)
                    folderSize(w: 140)
                }
                .padding(.horizontal, Theme.paddingM)
            }
            .padding(.vertical, Theme.paddingM)
        }
        .background(Theme.bg)
        .navigationTitle("Folder Gallery")
    }

    private func folderSize(w: CGFloat) -> some View {
        VStack(spacing: 4) {
            FolderView()
                .frame(width: w)
            Text("\(Int(w))pt")
                .font(.system(.caption2))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        FolderGalleryView()
    }
    .preferredColorScheme(.dark)
}
