import Foundation

/// Parses QR code payload from `openclaw qr --json`.
///
/// Expected format:
/// ```json
/// {
///   "gatewayUrl": "ws://192.168.1.100:18789",
///   "token": "0a7a1e581da3...",
///   "version": "2026.3.13"
/// }
/// ```
enum QRParser {
    
    struct QRPayload {
        let gatewayURL: URL
        let token: String
        let version: String?
    }
    
    enum QRError: Error, LocalizedError {
        case invalidData
        case invalidJSON
        case missingURL
        case missingToken
        case invalidURL(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidData: return "QR code is not valid text"
            case .invalidJSON: return "QR code is not valid JSON"
            case .missingURL: return "QR code missing gateway URL"
            case .missingToken: return "QR code missing auth token"
            case .invalidURL(let url): return "Invalid gateway URL: \(url)"
            }
        }
    }
    
    /// Parse QR code string into connection details
    static func parse(_ raw: String) -> Result<QRPayload, QRError> {
        guard let data = raw.data(using: .utf8) else {
            return .failure(.invalidData)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalidJSON)
        }
        
        guard let urlStr = json["gatewayUrl"] as? String ?? json["url"] as? String else {
            return .failure(.missingURL)
        }
        
        guard let token = json["token"] as? String else {
            return .failure(.missingToken)
        }
        
        guard let url = URL(string: urlStr) else {
            return .failure(.invalidURL(urlStr))
        }
        
        let version = json["version"] as? String
        
        return .success(QRPayload(
            gatewayURL: url,
            token: token,
            version: version
        ))
    }
}
