import SwiftUI
import PDFKit

struct FilePreviewView: View {
    let file: FileItem

    @State private var data: Data?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isFullscreen = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.border)

            if isLoading {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                errorView(error)
            } else {
                contentView
            }
        }
        .background(Theme.bg)
        .task { await loadFile() }
        .fullScreenCover(isPresented: $isFullscreen) {
            fullscreenHTML
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }

            Image(systemName: file.iconName)
                .foregroundColor(file.iconColor)

            Text(file.name)
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            if file.type == .html {
                Button {
                    isFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Menu {
                if let url = FileService.shared.fileURL(path: file.path) {
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
                    UIPasteboard.general.string = file.path
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, Theme.paddingM)
        .padding(.vertical, Theme.paddingS + 2)
        .background(Theme.surface)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch file.type {
        case .html:
            htmlPreview
        case .markdown:
            markdownPreview
        case .code:
            codePreview
        case .image:
            imagePreview
        case .pdf:
            pdfPreview
        case .json:
            jsonPreview
        case .unknown:
            plainTextPreview
        }
    }

    // MARK: - HTML (WKWebView with auth)

    private var htmlPreview: some View {
        Group {
            if let request = FileService.shared.authenticatedRequest(for: file.path) {
                WebContentView(request: request)
            } else {
                Text("Cannot build request")
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    @ViewBuilder
    private var fullscreenHTML: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    isFullscreen = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding()
            }
            .background(Color.black)

            if let request = FileService.shared.authenticatedRequest(for: file.path) {
                WebContentView(request: request)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    // MARK: - Markdown

    private var markdownPreview: some View {
        ScrollView {
            if let data, let text = String(data: data, encoding: .utf8) {
                let rendered = (try? AttributedString(markdown: text, options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                ))) ?? AttributedString(text)

                Text(rendered)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Code (monospaced, read-only)

    private var codePreview: some View {
        ScrollView([.horizontal, .vertical]) {
            if let data, let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .font(Theme.fontMono)
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Image (pinch-to-zoom)

    private var imagePreview: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text("Cannot display image")
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    // MARK: - PDF

    private var pdfPreview: some View {
        Group {
            if let data {
                PDFKitView(data: data)
            } else {
                Text("Cannot display PDF")
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    // MARK: - JSON (formatted)

    private var jsonPreview: some View {
        ScrollView([.horizontal, .vertical]) {
            if let data, let text = String(data: data, encoding: .utf8) {
                let pretty = Self.prettyJSON(text)
                Text(pretty)
                    .font(Theme.fontMono)
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Plain text fallback

    private var plainTextPreview: some View {
        ScrollView {
            if let data, let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .font(Theme.fontMono)
                    .foregroundColor(Theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(Theme.paddingM)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("\(data?.count ?? 0) bytes (binary)")
                    .font(Theme.fontCaption)
                    .foregroundColor(Theme.textMuted)
                    .padding(Theme.paddingM)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.paddingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(Theme.warning)
            Text(message)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
            Button("Retry") {
                Task { await loadFile() }
            }
            .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func loadFile() async {
        // HTML files load directly via WKWebView request — skip data fetch
        if file.type == .html {
            isLoading = false
            return
        }

        isLoading = true
        error = nil
        do {
            data = try await FileService.shared.getFile(path: file.path)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Helpers

    static func prettyJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return result
    }
}

#Preview("Code Preview") {
    FilePreviewView(file: FileItem(
        name: "app.swift",
        path: "app.swift",
        isDirectory: false,
        size: 256
    ))
    .preferredColorScheme(.dark)
}

#Preview("Markdown Preview") {
    FilePreviewView(file: FileItem(
        name: "README.md",
        path: "README.md",
        isDirectory: false,
        size: 1024
    ))
    .preferredColorScheme(.dark)
}

// MARK: - PDFKit wrapper

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil {
            pdfView.document = PDFDocument(data: data)
        }
    }
}
