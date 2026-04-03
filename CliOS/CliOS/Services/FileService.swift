import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.clios.app", category: "FileService")

enum FileServiceError: LocalizedError {
    case notConfigured
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Gateway not connected"
        case .httpError(let code): return "HTTP \(code)"
        case .invalidResponse: return "Invalid response"
        }
    }
}

@MainActor
class FileService: ObservableObject {
    static let shared = FileService()

    @Published var isLoading = false

    private var directoryCache: [String: [FileItem]] = [:]

    private init() {}

    // MARK: - URL building

    /// Base URL for canvas endpoint: http(s)://host:port/__openclaw__/canvas/
    var baseURL: URL? {
        guard let gwURL = GatewayService.shared.gatewayURL,
              let host = gwURL.host else { return nil }
        let scheme = (gwURL.scheme == "wss") ? "https" : "http"
        let port = gwURL.port ?? 18789
        return URL(string: "\(scheme)://\(host):\(port)/__openclaw__/canvas/")
    }

    private var token: String? { GatewayService.shared.authToken }

    /// Full URL for a file path (for WKWebView loading)
    func fileURL(path: String) -> URL? {
        baseURL?.appendingPathComponent(path)
    }

    // MARK: - List directory

    func listDirectory(path: String = "") async throws -> [FileItem] {
        if let cached = directoryCache[path] { return cached }

        guard let base = baseURL, let token = token else {
            throw FileServiceError.notConfigured
        }

        let url: URL
        if path.isEmpty {
            url = base
        } else {
            // Ensure trailing slash for directory listing
            let dirPath = path.hasSuffix("/") ? path : path + "/"
            url = base.appendingPathComponent(dirPath)
        }

        logger.info("Listing directory: \(url.absoluteString, privacy: .public)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FileServiceError.invalidResponse
        }

        guard http.statusCode == 200 else {
            throw FileServiceError.httpError(http.statusCode)
        }

        let html = String(data: data, encoding: .utf8) ?? ""
        let items = parseDirectoryListing(html: html, basePath: path)
            .sorted { lhs, rhs in
                // Directories first, then alphabetical
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        directoryCache[path] = items
        logger.info("Listed \(items.count) items in /\(path, privacy: .public)")
        return items
    }

    // MARK: - Get file content

    func getFile(path: String) async throws -> Data {
        guard let base = baseURL, let token = token else {
            throw FileServiceError.notConfigured
        }

        let url = base.appendingPathComponent(path)
        logger.info("Fetching file: \(url.absoluteString, privacy: .public)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FileServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return data
    }

    // MARK: - Authenticated URLRequest (for WKWebView)

    func authenticatedRequest(for path: String) -> URLRequest? {
        guard let url = fileURL(path: path), let token = token else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - Cache

    func clearCache() {
        directoryCache.removeAll()
    }

    func clearCache(path: String) {
        directoryCache.removeValue(forKey: path)
    }

    // MARK: - Parse HTML directory listing

    /// Parses nginx-style or simple HTML directory listings.
    /// Looks for <a href="name"> patterns, filters out parent links.
    private func parseDirectoryListing(html: String, basePath: String) -> [FileItem] {
        var items: [FileItem] = []

        // Match <a href="...">...</a> patterns
        let pattern = #"<a\s+[^>]*href="([^"]+)"[^>]*>([^<]*)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return items
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }

            let href = nsHTML.substring(with: match.range(at: 1))
            let displayName = nsHTML.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip parent directory links and query/fragment links
            if href == "../" || href == ".." || href == "/" || href == "./" { continue }
            if href.hasPrefix("?") || href.hasPrefix("#") { continue }
            if href.hasPrefix("http://") || href.hasPrefix("https://") { continue }

            let isDir = href.hasSuffix("/")
            let cleanName = isDir ? String(href.dropLast()) : href
            let name = cleanName.removingPercentEncoding ?? cleanName

            // Skip hidden files starting with .
            if name.hasPrefix(".") { continue }

            let itemPath: String
            if basePath.isEmpty {
                itemPath = name
            } else {
                let base = basePath.hasSuffix("/") ? basePath : basePath + "/"
                itemPath = base + name
            }

            // Try to extract size from the listing line (nginx format: "01-Jan-2024 12:00  1234")
            let size = extractSize(from: html, near: href)

            items.append(FileItem(
                name: name,
                path: itemPath,
                isDirectory: isDir,
                size: isDir ? nil : size
            ))
        }

        return items
    }

    /// Tries to extract file size from nginx-style directory listing HTML near a given href.
    private func extractSize(from html: String, near href: String) -> Int? {
        // Look for the line containing this href and find a size number after the date
        // nginx format: <a href="file.txt">file.txt</a>  01-Jan-2024 12:00  1234\n
        guard let hrefRange = html.range(of: href) else { return nil }
        let afterHref = html[hrefRange.upperBound...]
        guard let lineEnd = afterHref.firstIndex(of: "\n") else { return nil }
        let line = String(afterHref[..<lineEnd])

        // Find the last number on the line (that's usually the size)
        let sizePattern = #"\s(\d+)\s*$"#
        guard let sizeRegex = try? NSRegularExpression(pattern: sizePattern),
              let sizeMatch = sizeRegex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
              sizeMatch.numberOfRanges >= 2 else {
            return nil
        }

        let sizeStr = (line as NSString).substring(with: sizeMatch.range(at: 1))
        return Int(sizeStr)
    }
}
