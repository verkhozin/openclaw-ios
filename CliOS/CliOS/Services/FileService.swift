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

    // MARK: - List directory (via WebSocket agents.files.list)

    func listDirectory(path: String = "") async throws -> [FileItem] {
        if let cached = directoryCache[path] { return cached }

        guard GatewayService.shared.status.isConnected else {
            throw FileServiceError.notConfigured
        }

        logger.info("Listing directory via WebSocket: /\(path, privacy: .public)")

        var params: [String: Any] = ["agentId": "scout"]
        if !path.isEmpty {
            params["path"] = path
        }

        let payload = try await GatewayService.shared.sendRequest(
            method: "agents.files.list",
            params: params
        )

        let items = parseFilesListResponse(payload, basePath: path)
            .sorted { lhs, rhs in
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

    // MARK: - Parse agents.files.list response

    /// Parses the payload from agents.files.list WebSocket response.
    /// Expected format: { "files": [ { "name": "...", "type": "file"|"directory", "size": 123 }, ... ] }
    private func parseFilesListResponse(_ payload: [String: Any], basePath: String) -> [FileItem] {
        // Try "files" key first, then "entries", then treat payload itself as array container
        let entries: [[String: Any]]
        if let files = payload["files"] as? [[String: Any]] {
            entries = files
        } else if let items = payload["entries"] as? [[String: Any]] {
            entries = items
        } else if let items = payload["items"] as? [[String: Any]] {
            entries = items
        } else {
            logger.warning("No files array found in response: \(payload.keys.joined(separator: ", "), privacy: .public)")
            return []
        }

        return entries.compactMap { entry -> FileItem? in
            guard let name = entry["name"] as? String else { return nil }

            // Skip hidden files
            if name.hasPrefix(".") { return nil }

            let isDir = (entry["type"] as? String) == "directory"
                || (entry["isDirectory"] as? Bool) == true
            let size = entry["size"] as? Int

            let itemPath: String
            if basePath.isEmpty {
                itemPath = name
            } else {
                let base = basePath.hasSuffix("/") ? basePath : basePath + "/"
                itemPath = base + name
            }

            return FileItem(
                name: name,
                path: itemPath,
                isDirectory: isDir,
                size: isDir ? nil : size
            )
        }
    }
}
