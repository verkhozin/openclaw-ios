import SwiftUI

struct FileExplorerView: View {
    @StateObject private var fileService = FileService.shared
    @EnvironmentObject var gateway: GatewayService

    @State private var currentPath: String = ""
    @State private var items: [FileItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedFile: FileItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                breadcrumb
                Divider().background(Theme.border)
                fileList
            }
            .background(Theme.bg)
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedFile) { file in
                FilePreviewView(file: file)
                    .navigationBarHidden(true)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    navigateTo(path: "")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 12))
                        Text("workspace")
                            .font(Theme.fontMonoSmall)
                    }
                    .foregroundColor(currentPath.isEmpty ? Theme.accent : Theme.textSecondary)
                }

                ForEach(pathSegments, id: \.path) { segment in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.textMuted)

                    Button {
                        navigateTo(path: segment.path)
                    } label: {
                        Text(segment.name)
                            .font(Theme.fontMonoSmall)
                            .foregroundColor(segment.path == currentPath ? Theme.accent : Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, Theme.paddingS)
        }
        .background(Theme.surface)
    }

    private var pathSegments: [(name: String, path: String)] {
        guard !currentPath.isEmpty else { return [] }
        let parts = currentPath.split(separator: "/").map(String.init)
        var segments: [(String, String)] = []
        for (i, part) in parts.enumerated() {
            let path = parts[0...i].joined(separator: "/")
            segments.append((part, path))
        }
        return segments
    }

    // MARK: - File list

    private var fileList: some View {
        Group {
            if isLoading && items.isEmpty {
                VStack(spacing: Theme.paddingM) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("Loading...")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: Theme.paddingM) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.warning)
                    Text(error)
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadDirectory()
                    }
                    .foregroundColor(Theme.accent)
                }
                .padding(Theme.paddingL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: Theme.paddingM) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textMuted)
                    Text("Empty directory")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        FileRow(item: item)
                            .listRowBackground(Theme.surface)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleTap(item)
                            }
                            .contextMenu {
                                fileContextMenu(for: item)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    fileService.clearCache(path: currentPath)
                    await loadDirectoryAsync()
                }
            }
        }
        .task { loadDirectory() }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func fileContextMenu(for item: FileItem) -> some View {
        Button {
            UIPasteboard.general.string = item.path
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }

        if !item.isDirectory, let url = fileService.fileURL(path: item.path) {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                UIApplication.shared.open(url)
            } label: {
                Label("Open in Safari", systemImage: "safari")
            }
        }

        Button {
            askAgent(about: item)
        } label: {
            Label("Ask Agent", systemImage: "bubble.left")
        }
    }

    // MARK: - Actions

    private func handleTap(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(path: item.path)
        } else {
            selectedFile = item
        }
    }

    private func navigateTo(path: String) {
        currentPath = path
        items = []
        error = nil
        loadDirectory()
    }

    private func loadDirectory() {
        Task { await loadDirectoryAsync() }
    }

    private func loadDirectoryAsync() async {
        isLoading = true
        error = nil
        do {
            items = try await fileService.listDirectory(path: currentPath)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func askAgent(about item: FileItem) {
        gateway.sendMessage("Tell me about \(item.path)")
    }
}

// MARK: - Preview

private let previewItems: [FileItem] = [
    FileItem(name: "landing", path: "landing", isDirectory: true, size: nil),
    FileItem(name: "assets", path: "assets", isDirectory: true, size: nil),
    FileItem(name: "scripts", path: "scripts", isDirectory: true, size: nil),
    FileItem(name: "v4-flux.html", path: "v4-flux.html", isDirectory: false, size: 24_310),
    FileItem(name: "README.md", path: "README.md", isDirectory: false, size: 1_842),
    FileItem(name: "config.json", path: "config.json", isDirectory: false, size: 512),
    FileItem(name: "app.swift", path: "app.swift", isDirectory: false, size: 3_200),
    FileItem(name: "hero.png", path: "hero.png", isDirectory: false, size: 185_400),
    FileItem(name: "report.pdf", path: "report.pdf", isDirectory: false, size: 52_000),
    FileItem(name: "TODO.md", path: "TODO.md", isDirectory: false, size: 320),
]

#Preview("File Explorer") {
    FileExplorerPreview()
        .preferredColorScheme(.dark)
}

/// Static preview that doesn't hit network.
private struct FileExplorerPreview: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Breadcrumb
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "externaldrive.connected.to.line.below")
                                .font(.system(size: 12))
                            Text("workspace")
                                .font(Theme.fontMonoSmall)
                        }
                        .foregroundColor(Theme.accent)
                    }
                    .padding(.horizontal, Theme.paddingM)
                    .padding(.vertical, Theme.paddingS)
                }
                .background(Theme.surface)

                Divider().background(Theme.border)

                // File list
                List {
                    ForEach(previewItems) { item in
                        FileRow(item: item)
                            .listRowBackground(Theme.surface)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.bg)
        }
    }
}

#Preview("File Row") {
    List {
        ForEach(previewItems) { item in
            FileRow(item: item)
                .listRowBackground(Theme.surface)
        }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Theme.bg)
    .preferredColorScheme(.dark)
}

// MARK: - File Row

struct FileRow: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.system(size: 20))
                .foregroundColor(item.iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                if let size = item.formattedSize {
                    Text(size)
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.textMuted)
                }
            }

            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.vertical, 4)
    }
}
